# frozen_string_literal: true

# An extension to the DDEService that provides merging functionality
# for local patients and remote patients
class DDEMergingService
  include ModelUtils

  attr_accessor :parent, :dde_client

  # Initialise DDE's merging service.
  #
  # Parameters:
  #   parent: Is the parent DDE service
  #   dde_client: Is a configured DDE client
  def initialize(parent, dde_client)
    @parent = parent
    @dde_client = dde_client
  end

  # Merge secondary patient(s) into primary patient.
  #
  # Parameters:
  #   primary_patient_ids - An object of them form { 'patient_id' => xxx, 'doc_id' }.
  #                         One of 'patient_id' and 'doc_id' must be present else an
  #                         InvalidParametersError be thrown.
  #   secondary_patient_ids_list - An array of objects like that for 'primary_patient_ids'
  #                                above
  def merge_patients(primary_patient_ids, secondary_patient_ids_list)
    secondary_patient_ids_list.collect do |secondary_patient_ids|
      if remote_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_patients(primary_patient_ids, secondary_patient_ids)
      elsif remote_local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids)
      elsif inverted_remote_local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_and_local_patients(secondary_patient_ids, primary_patient_ids)
      elsif local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_local_patients(primary_patient_ids, secondary_patient_ids)
      else
        raise InvalidParameterError,
              "Invalid merge parameters: primary => #{primary_patient_ids}, secondary => #{secondary_patient_ids}"
      end
    end.first
  end

  # Merges @{param secondary_patient} into @{param primary_patient}.
  def merge_local_patients(primary_patient_ids, secondary_patient_ids)
    ActiveRecord::Base.transaction do
      primary_patient = Patient.find(primary_patient_ids['patient_id'])
      secondary_patient = Patient.find(secondary_patient_ids['patient_id'])

      merge_name(primary_patient, secondary_patient)
      merge_identifiers(primary_patient, secondary_patient)
      merge_attributes(primary_patient, secondary_patient)
      merge_address(primary_patient, secondary_patient)
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
    national_id_type = patient_identifier_type('National id')
    doc_id_type = patient_identifier_type('DDE person document id')

    local_patient.patient_identifiers.where(type: [national_id_type, doc_id_type]) .each do |identifier|
      if identifier.identifier_type == national_id_type.id && identifier.identifier.match?(/^\s*P\d{12}\s*$/i)
        # We have a v3 NPID that should get demoted to legacy national id
        create_local_patient_identifier(local_patient, identifier.identifier, 'Old Identification Number')
      end

      identifier.void("Assigned new id: #{remote_patient['doc_id']}")
    end

    create_local_patient_identifier(local_patient, remote_patient['doc_id'], 'DDE person document id')
    create_local_patient_identifier(local_patient, find_remote_patient_npid(remote_patient), 'National id')

    local_patient.reload
    local_patient
  end

  private

  # Checks whether the passed parameters are enough for a remote merge.
  #
  # The precondition for a remote merge is the presence of a doc_id
  # in both primary and secondary patient ids.
  def remote_merge?(primary_patient_ids, secondary_patient_ids)
    !(primary_patient_ids['doc_id'].blank? || secondary_patient_ids['doc_id'].blank?)
  end

  # Is a merge of a remote patient into a local patient possible?
  def remote_local_merge?(primary_patient_ids, secondary_patient_ids)
    !(primary_patient_ids['patient_id'].blank? || secondary_patient_ids['doc_id'].blank?)
  end

  # Like `remote_local_merge` but primary is remote and secondary is local
  def inverted_remote_local_merge?(primary_patient_ids, secondary_patient_ids)
    !(primary_patient_ids['doc_id'].blank? || secondary_patient_ids['patient_id'].blank?)
  end

  # Is a merge of local patients possible?
  def local_merge?(primary_patient_ids, secondary_patient_ids)
    !(primary_patient_ids['patient_id'].blank? || secondary_patient_ids['patient_id'].blank?)
  end

  # Merge remote secondary patient into local primary patient
  def merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids)
    local_patient = Patient.find(primary_patient_ids['patient_id'])
    remote_patient = reassign_remote_patient_npid(secondary_patient_ids['doc_id'])

    local_patient = link_local_to_remote_patient(local_patient, remote_patient)
    return local_patient if secondary_patient_ids['patient_id'].blank?

    merge_local_patients(primary_patient_ids, secondary_patient_ids)
  end

  # Merge patients in DDE and update local records if need be
  def merge_remote_patients(primary_patient_ids, secondary_patient_ids)
    response, status = dde_client.post('merge_people', primary_person_doc_id: primary_patient_ids['doc_id'],
                                                       secondary_person_doc_id: secondary_patient_ids['doc_id'])

    raise "Failed to merge patients on remote: #{status} - #{response}" unless status == 200

    return parent.save_remote_patient(response) if primary_patient_ids['patient_id'].blank?

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

  # Patch primary_patient missing name data using secondary_patient
  def merge_name(primary_patient, secondary_patient)
    primary_name = primary_patient.person.names.first
    secondary_name = secondary_patient.person.names.first

    return unless secondary_name

    secondary_name_hash = secondary_name.as_json

    # primary patient doesn't have a name, so just copy secondary patient's
    unless primary_name
      secondary_name_hash.delete('uuid')
      secondary_name_hash.delete('person_name_id')
      secondary_name_hash.delete('creator')
      secondary_name_hash['person_id'] = primary_patient.patient_id
      primary_name = PersonName.create(secondary_name_hash)
      raise "Could not merge patient name: #{primary_name.errors.as_json}" unless primary_name.errors.empty?

      secondary_name.void("Merged into patient ##{primary_patient.patient_id}")
      return
    end

    params = primary_name.as_json.each_with_object({}) do |(field, value), params|
      secondary_value = secondary_name_hash[field]

      next unless value.blank? && !secondary_value.blank?

      params[field] = secondary_value
    end

    primary_name.update(params)
    secondary_name.void("Merged into person ##{primary_patient.patient_id}")
  end

  # Bless primary_patient with identifiers available only to the secondary patient
  def merge_identifiers(primary_patient, secondary_patient)
    secondary_patient.patient_identifiers.each do |identifier|
      next if primary_patient.patient_identifiers.where(identifier_type: identifier.identifier_type).exists?

      new_identifier = PatientIdentifier.create(patient_id: primary_patient.patient_id,
                                                identifier_type: identifier.identifier_type,
                                                identifier: identifier.identifier,
                                                location_id: identifier.location_id)
      raise "Could not merge patient identifier: #{new_identifier.errors.as_json}" unless new_identifier.errors.empty?

      identifier.void("Merged into patient ##{primary_patient.patient_id}")
    end
  end

  # Patch primary_patient missing attributes using secondary patient data
  def merge_attributes(primary_patient, secondary_patient)
    secondary_patient.person.person_attributes.each do |attribute|
      next if primary_patient.person.person_attributes.where(
        person_attribute_type_id: attribute.person_attribute_type_id
      ).exists?

      new_attribute = PersonAttribute.create(person_id: primary_patient.patient_id,
                                             person_attribute_type_id: attribute.person_attribute_type_id,
                                             value: attribute.value)
      raise "Could not merge patient attribute: #{new_attribute.errors.as_json}" unless new_attribute.errors.empty?

      attribute.void("Merged into patient ##{primary_patient.patient_id}")
    end
  end

  # Patch primary missing patient address data using from secondary patient address
  def merge_address(primary_patient, secondary_patient)
    primary_address = primary_patient.person.addresses.first
    secondary_address = secondary_patient.person.addresses.first

    return unless secondary_address

    secondary_address_hash = secondary_address.as_json

    unless primary_address
      secondary_address_hash.delete('uuid')
      secondary_address_hash.delete('person_address_id')
      secondary_address_hash.delete('creator')
      secondary_address_hash['person_id'] = primary_patient.patient_id
      primary_address = PersonAddress.create(secondary_address_hash)
      raise "Could not merge patient address: #{primary_address.errors.as_json}" unless primary_address.errors.empty?

      secondary_address.void("Merged into patient ##{primary_patient.patient_id}")
      return
    end

    params = primary_address.as_json.each_with_object({}) do |(field, value), params|
      secondary_value = secondary_address_hash[field]

      next unless value.blank? && !secondary_value.blank?

      params[field] = secondary_value
    end

    primary_address.update(params)
    secondary_address.void("Merged into person ##{primary_patient.patient_id}")
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

  def find_remote_patient_npid(remote_patient)
    npid = remote_patient['npid']
    return npid unless npid.blank?

    remote_patient['identifiers'].each do |identifier|
      # NOTE: DDE returns identifiers as either a list of maps of
      # identifier_type => identifier or simply a map of
      # identifier_type => identifier. In the latter case the NPID is
      # not included in the identifiers object hence returning nil.
      return nil if identifier.class == Array

      npid = identifier['National patient identifier']
      return npid unless npid.blank?
    end

    nil
  end

  # Convert a DDE person to an openmrs person.
  #
  # NOTE: This creates a person on the database.
  def save_remote_patient(remote_patient)
    LOGGER.debug "Converting DDE person to openmrs: #{remote_patient}"

    person = person_service.create_person(
      birthdate: remote_patient['birthdate'],
      birthdate_estimated: remote_patient['birthdate_estimated'],
      gender: remote_patient['gender']
    )

    person_service.create_person_name(
      person, given_name: remote_patient['given_name'],
              family_name: remote_patient['family_name'],
              middle_name: remote_patient['middle_name']
    )

    remote_patient_attributes = remote_patient['attributes']
    person_service.create_person_address(
      person, home_village: remote_patient_attributes['home_village'],
              home_traditional_authority: remote_patient_attributes['home_traditional_authority'],
              home_district: remote_patient_attributes['home_district'],
              current_village: remote_patient_attributes['current_village'],
              current_traditional_authority: remote_patient_attributes['current_traditional_authority'],
              current_district: remote_patient_attributes['current_district']
    )

    person_service.create_person_attributes(
      person, cell_phone_number: remote_patient_attributes['cellphone_number'],
              occupation: remote_patient_attributes['occupation']
    )

    patient = Patient.create(patient_id: person.id)
    merging_service.link_local_to_remote_patient(patient, remote_patient)
  end

  def patient_service
    PatientService.new
  end

  def dde_client
    if @dde_client.respond_to?(:call)
      # HACK: Allows the dde_client to be passed in as a callable to be passed
      #   in as a callable to enable lazy instantiation. The dde_client is
      #   not required for local merges (thus no need to instantiate it).
      @dde_client.call
    else
      @dde_client
    end
  end
end
