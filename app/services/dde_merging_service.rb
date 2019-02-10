# frozen_string_literal: true

# An extension to the DDEService that provides merging functionality
# for local patients and remote patients
class DDEMergingService
  include ModelUtils

  attr_accessor :dde_client, :patient_service

  def initialize(dde_client)
    @dde_client = dde_client
    @patient_service = patient_service
  end

  def merge_patients(primary_patient_ids, secondary_patient_ids)
    if remote_merge?(primary_patient_ids, secondary_patient_ids)
      merge_remote_patients(primary_patient_ids, secondary_patient_ids)
    elsif remote_local_merge?(primary_patient_ids, secondary_patient_ids)
      merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids)
    elsif local_merge?(primary_patient_ids, secondary_patient_ids)
      merge_local_patients(primary_patient_ids, secondary_patient_ids)
    else
      raise "Invalid merge parameters: primary => #{primary_patient_ids}, secondary => #{secondary_patient_ids}"
    end
  end

  # Merges @{param secondary_patient} into @{param primary_patient}.
  def merge_local_patients(primary_patient_ids, secondary_patient_ids)
    ActiveRecord::Base.transaction do
      primary_patient = Patient.find(primary_patient_ids['patient_id'])
      secondary_patient = Patient.find(secondary_patient_ids['patient_id'])

      merge_orders(primary_patient, secondary_patient)
      merge_observations(primary_patient, secondary_patient)
      merge_encounters(primary_patient, secondary_patient)
      secondary_patient.void("Merged into patient ##{primary_patient.id}")

      primary_patient
    end
  end

  # Binds the remote patient to the local patient by blessing the local patient
  # with the remotes npid and doc_id
  def link_local_to_remote_patient(local_patient, remote_patient)
    local_patient.identifier('DDE person document id')&.void("Assigned new id: #{remote_patient['doc_id']}")
    local_patient.identifier('National id')&.void("Assigned new id: #{remote_patient['npid']}")

    create_local_patient_identifier(local_patient, remote_patient['doc_id'], 'DDE person document id')
    create_local_patient_identifier(local_patient, remote_patient['npid'], 'National id')

    local_patient.reload
    local_patient
  end

  private

  # Checks whether the passed parameters are enough for a remote merge.
  #
  # The precondition for a remote merge is the presence of a doc_id
  # in both primary and secondary patient ids.
  def remote_merge?(primary_patient_ids, secondary_patient_ids)
    primary_patient_ids['doc_id'] && secondary_patient_ids['doc_id']
  end

  # Is a merge of a remote patient into a local patient possible?
  def remote_local_merge?(primary_patient_ids, secondary_patient_ids)
    primary_patient_ids['patient_id'] && secondary_patient_ids['doc_id']
  end

  # Is a merge of local patients possible?
  def local_merge?(primary_patient_ids, secondary_patient_ids)
    primary_patient_ids['patient_id'] && secondary_patient_ids['patient_id']
  end

  # Merge remote secondary patient into local primary patient
  def merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids)
    local_patient = Patient.find(primary_patient_ids['patient_id'])
    remote_patient = reassign_remote_patient_npid(secondary_patient_ids['doc_id'])

    local_patient = link_local_to_remote_patient(local_patient, remote_patient)
    return local_patient if secondary_patient_ids['patient_id'].blank?

    merge_local_patients(local_patient, Patient.find(secondary_patient_ids['patient_id']))
  end

  # Merge patients in DDE and update local records if need be
  def merge_remote_patients(primary_patient_ids, secondary_patient_ids)
    response, status = dde_client.post('merge_people', primary_person_doc_id: primary_patient_ids['doc_id'],
                                                       secondary_person_doc_id: secondary_patient_ids['doc_id'])

    raise "Failed to merge patients on remote: #{status} - #{response}" unless status == 200

    return save_remote_patient(response) if primary_patient_ids['patient_id'].blank?

    local_patient = link_local_to_remote_patient(Patient.find(primary_patient_ids['patient_id']), response)
    return local_patient if secondary_patient_ids['patient_id'].blank?

    merge_local_patients(local_patient, Patient.find(secondary_patient_ids['patient_id']))
  end

  def create_local_patient_identifier(patient, value, type_name)
    identifier = PatientIdentifier.create(identifier: value,
                                          type: patient_identifier_type(type_name),
                                          location_id: Location.current.id,
                                          patient: patient)
    return patient.reload && identifier if identifier.errors.empty?

    raise "Could not save DDE identifier: #{type_name} due to #{identifier.errors.as_json}"
  end

  # Strips off secondary_patient all orders and blesses primary patient
  # with them
  def merge_orders(primary_patient, secondary_patient)
    Rails.logger.debug("Merging patient orders: #{primary_patient} <= #{secondary_patient}")

    primary_patient_id = ActiveRecord::Base.connection.quote(primary_patient.id)
    secondary_patient_id = ActiveRecord::Base.connection.quote(secondary_patient.id)

    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE orders SET patient_id = #{primary_patient_id}
      WHERE patient_id = #{secondary_patient_id} AND voided = 0
    SQL
  end

  # Strips off secondary_patient all observations and blesses primary patient
  # with them
  def merge_observations(primary_patient, secondary_patient)
    Rails.logger.debug("Merging patient observations: #{primary_patient} <= #{secondary_patient}")

    primary_patient_id = ActiveRecord::Base.connection.quote(primary_patient.id)
    secondary_patient_id = ActiveRecord::Base.connection.quote(secondary_patient.id)

    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE obs SET person_id = #{primary_patient_id}
      WHERE person_id = #{secondary_patient_id} AND voided = 0
    SQL
  end

  # Strips off secondary_patient all encounters and blesses primary patient
  # with them
  def merge_encounters(primary_patient, secondary_patient)
    Rails.logger.debug("Merging patient encounters: #{primary_patient} <= #{secondary_patient}")

    primary_patient_id = ActiveRecord::Base.connection.quote(primary_patient.id)
    secondary_patient_id = ActiveRecord::Base.connection.quote(secondary_patient.id)

    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE encounter SET patient_id = #{primary_patient_id}
      WHERE patient_id = #{secondary_patient_id} AND voided = 0
    SQL
  end

  def reassign_remote_patient_npid(patient_doc_id)
    response, status = dde_client.post('reassign_npid', { doc_id: patient_doc_id })

    unless status == 200
      raise "Failed to reassign remote patient npid: DDE Response => #{status} - #{response}"
    end

    response
  end

  def patient_service
    PatientService.new
  end
end
