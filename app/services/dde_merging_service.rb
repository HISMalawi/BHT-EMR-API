# frozen_string_literal: true

# An extension to the DDEService that provides merging functionality
# for local patients and remote patients
class DDEMergingService
  include ModelUtils

  attr_accessor :parent

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
      if !dde_enabled?
        merge_local_patients(primary_patient_ids, secondary_patient_ids, 'Local Patients')
      elsif remote_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_patients(primary_patient_ids, secondary_patient_ids)
      elsif remote_local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids, 'Remote and Local Patient')
      elsif inverted_remote_local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_remote_and_local_patients(secondary_patient_ids, primary_patient_ids, 'Local and Remote Patients')
      elsif local_merge?(primary_patient_ids, secondary_patient_ids)
        merge_local_patients(primary_patient_ids, secondary_patient_ids, 'Local Patients')
      else
        raise InvalidParameterError,
              "Invalid merge parameters: primary => #{primary_patient_ids}, secondary => #{secondary_patient_ids}"
      end
    end.first
  end

  # Merges @{param secondary_patient} into @{param primary_patient}.
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def merge_local_patients(primary_patient_ids, secondary_patient_ids, merge_type)
    ActiveRecord::Base.transaction do
      primary_patient = Patient.find(primary_patient_ids['patient_id'])
      secondary_patient = Patient.find(secondary_patient_ids['patient_id'])
      merge_name(primary_patient, secondary_patient)
      merge_identifiers(primary_patient, secondary_patient)
      merge_attributes(primary_patient, secondary_patient)
      merge_address(primary_patient, secondary_patient)
      @obs_map = {}
      if female_male_merge?(primary_patient, secondary_patient) && secondary_female?(secondary_patient)
        void_program_encounter(primary_patient, secondary_patient, 'CxCa program')
        void_program_encounter(primary_patient, secondary_patient, 'ANC PROGRAM')
      end
      result = merge_encounters(primary_patient, secondary_patient)
      merge_observations(primary_patient, secondary_patient, result)
      merge_orders(primary_patient, secondary_patient, result)
      MergeAuditService.new.create_merge_audit(primary_patient.id, secondary_patient.id, merge_type)
      secondary_patient.void("Merged into patient ##{primary_patient.id}:0")

      primary_patient
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # Binds the remote patient to the local patient by blessing the local patient
  # with the remotes npid and doc_id
  def link_local_to_remote_patient(local_patient, remote_patient)
    return local_patient if local_patient_linked_to_remote?(local_patient, remote_patient)

    national_id_type = patient_identifier_type('National id')
    old_identifier = patient_identifier_type('Old Identification Number')
    doc_id_type = patient_identifier_type('DDE person document id')

    local_patient.patient_identifiers.where(type: [national_id_type, doc_id_type, old_identifier]).each do |identifier|
      # We are now voiding all ids
      # if identifier.identifier_type == national_id_type.id && identifier.identifier.match?(/^\s*P\d{12}\s*$/i)
      #   # We have a v3 NPID that should get demoted to legacy national id
      #   create_local_patient_identifier(local_patient, identifier.identifier, 'Old Identification Number')
      # end

      identifier.void("Assigned new id: #{remote_patient['doc_id']}")
    end

    create_local_patient_identifier(local_patient, remote_patient['doc_id'], 'DDE person document id')
    create_local_patient_identifier(local_patient, find_remote_patient_npid(remote_patient), 'National id')

    local_patient.reload
    local_patient
  end

  def local_patient_linked_to_remote?(local_patient, remote_patient)
    identifier_exists = lambda do |type, value|
      PatientIdentifier.where(patient: local_patient, type: PatientIdentifierType.where(name: type), identifier: value)
                       .exists?
    end

    identifier_exists['National id',
                      remote_patient['npid']] && identifier_exists['DDE person document id', remote_patient['doc_id']]
  end

  private

  # Checks whether the passed parameters are enough for a remote merge.
  #
  # The precondition for a remote merge is the presence of a doc_id
  # in both primary and secondary patient ids.
  def remote_merge?(primary_patient_ids, secondary_patient_ids)
    !primary_patient_ids['doc_id'].blank? && !secondary_patient_ids['doc_id'].blank?
  end

  # Is a merge of a remote patient into a local patient possible?
  def remote_local_merge?(primary_patient_ids, secondary_patient_ids)
    !primary_patient_ids['patient_id'].blank? && !secondary_patient_ids['doc_id'].blank?
  end

  # Like `remote_local_merge` but primary is remote and secondary is local
  def inverted_remote_local_merge?(primary_patient_ids, secondary_patient_ids)
    !primary_patient_ids['doc_id'].blank? && !secondary_patient_ids['patient_id'].blank?
  end

  # Is a merge of local patients possible?
  def local_merge?(primary_patient_ids, secondary_patient_ids)
    !primary_patient_ids['patient_id'].blank? && !secondary_patient_ids['patient_id'].blank?
  end

  # Merge remote secondary patient into local primary patient
  def merge_remote_and_local_patients(primary_patient_ids, secondary_patient_ids, merge_type)
    local_patient = Patient.find(primary_patient_ids['patient_id'])
    remote_patient = reassign_remote_patient_npid(secondary_patient_ids['doc_id'])

    local_patient = link_local_to_remote_patient(local_patient, remote_patient)
    return local_patient if secondary_patient_ids['patient_id'].blank?

    merge_local_patients(primary_patient_ids, secondary_patient_ids, merge_type)
  end

  # Merge patients in DDE and update local records if need be
  def merge_remote_patients(primary_patient_ids, secondary_patient_ids)
    response, status = dde_client.post('merge_people', primary_person_doc_id: primary_patient_ids['doc_id'],
                                                       secondary_person_doc_id: secondary_patient_ids['doc_id'])

    raise "Failed to merge patients on remote: #{status} - #{response}" unless status == 200

    return parent.save_remote_patient(response) if primary_patient_ids['patient_id'].blank?

    local_patient = link_local_to_remote_patient(Patient.find(primary_patient_ids['patient_id']), response)
    return local_patient if secondary_patient_ids['patient_id'].blank?

    merge_local_patients(local_patient, Patient.find(secondary_patient_ids['patient_id']), 'Remote Patients')
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

      secondary_name.void("Merged into patient ##{primary_patient.patient_id}:#{primary_name.id}")
      return
    end

    params = primary_name.as_json.each_with_object({}) do |(field, value), params|
      secondary_value = secondary_name_hash[field]

      next unless value.blank? && !secondary_value.blank?

      params[field] = secondary_value
    end

    primary_name.update(params)
    secondary_name.void("Merged into patient ##{primary_patient.patient_id}:0")
  end

  NATIONAL_ID_TYPE = PatientIdentifierType.find_by_name!('National ID')
  OLD_NATIONAL_ID_TYPE = PatientIdentifierType.find_by_name!('Old Identification Number')

  # Bless primary_patient with identifiers available only to the secondary patient
  def merge_identifiers(primary_patient, secondary_patient)
    secondary_patient.patient_identifiers.each do |identifier|
      next if patient_has_identifier(primary_patient, identifier.identifier_type, identifier.identifier)

      new_identifier = PatientIdentifier.create(
        patient_id: primary_patient.patient_id,
        location_id: identifier.location_id,
        identifier: identifier.identifier,
        identifier_type: if identifier.identifier_type == NATIONAL_ID_TYPE.id
                           # Can't have two National Patient IDs, the secondary ones are treated as old identifiers
                           OLD_NATIONAL_ID_TYPE.id
                         else
                           identifier.identifier_type
                         end
      )
      raise "Could not merge patient identifier: #{new_identifier.errors.as_json}" unless new_identifier.errors.empty?

      identifier.void("Merged into patient ##{primary_patient.patient_id}: #{new_identifier.id}")
    end
  end

  def patient_has_identifier(patient, identifier_type_id, identifier_value)
    patient.patient_identifiers
           .where(identifier_type: identifier_type_id, identifier: identifier_value)
           .exists?
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

      attribute.void("Merged into patient ##{primary_patient.patient_id}:#{new_attribute.id}")
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

      secondary_address.void("Merged into patient ##{primary_patient.patient_id}:#{primary_address.id}")
      return
    end

    params = primary_address.as_json.each_with_object({}) do |(field, value), params|
      secondary_value = secondary_address_hash[field]

      next unless value.blank? && !secondary_value.blank?

      params[field] = secondary_value
    end

    primary_address.update(params)
    secondary_address.void("Merged into patient ##{primary_patient.patient_id}:0")
  end

  # Strips off secondary_patient all orders and blesses primary patient
  # with them
  def merge_orders(primary_patient, secondary_patient, encounter_map)
    Rails.logger.debug("Merging patient orders: #{primary_patient} <= #{secondary_patient}")
    orders_map = {}
    Order.where(patient_id: secondary_patient.id).each do |order|
      check = Order.find_by('order_type_id = ? AND concept_id = ? AND patient_id = ? AND DATE(start_date) = ?',
                            order.order_type_id, order.concept_id, primary_patient.id, order.start_date.strftime('%Y-%m-%d'))
      if check.blank?
        primary_order_hash = order.attributes
        primary_order_hash.delete('order_id')
        primary_order_hash.delete('uuid')
        primary_order_hash.delete('creator')
        primary_order_hash.delete('order_id')
        primary_order_hash['patient_id'] = primary_patient.id
        primary_order_hash['encounter_id'] = encounter_map[order.encounter_id]
        primary_order_hash['obs_id'] = @obs_map[order.obs_id] unless order.obs_id.blank?
        primary_order = Order.create(primary_order_hash)
        raise "Could not merge patient orders: #{primary_order.errors.as_json}" unless primary_order.errors.empty?

        order.void("Merged into patient ##{primary_patient.patient_id}:#{primary_order.id}")
        orders_map[order.id] = primary_order.id
      else
        order.void("Merged into patient ##{primary_patient.patient_id}:0")
        orders_map[order.id] = check.id
      end
    end

    manage_drug_order orders_map
    update_obs_order_id(orders_map, @obs_map)
  end

  # method to update drug orders with the new order id
  def manage_drug_order(order_map)
    result = ActiveRecord::Base.connection.select_all "SELECT * FROM drug_order WHERE order_id IN (#{order_map.keys.join(',')})"
    return if result.blank?

    result.each do |drug_order|
      new_id = order_map[drug_order['order_id']]
      next if DrugOrder.where(order_id: new_id)

      drug_order['order_id'] = new_id
      new_drug_order = DrugOrder.create(drug_order)
      raise "Could not merge patient druge orders: #{new_drug_order.errors.as_json}" unless new_drug_order.errors.empty?
    end
  end

  def update_obs_order_id(order_map, obs_map)
    Observation.where(obs_id: obs_map.values).each do |obs|
      obs.update(order_id: order_map[obs.order_id]) unless obs.order_id.blank?
    end
  end

  # Strips off secondary_patient all observations and blesses primary patient
  # with them
  def merge_observations(primary_patient, secondary_patient, encounter_map)
    Rails.logger.debug("Merging patient observations: #{primary_patient} <= #{secondary_patient}")

    Observation.where(person_id: secondary_patient.id).each do |obs|
      check = Observation.find_by("person_id = #{primary_patient.id} AND concept_id = #{obs.concept_id} AND
        DATE(obs_datetime) = DATE('#{obs.obs_datetime.strftime('%Y-%m-%d')}') #{unless obs.value_coded.blank?
                                                                                  "AND value_coded = #{obs.value_coded}"
                                                                                end}")
      if check.blank?
        primary_obs = process_obervation_merging(obs, primary_patient, encounter_map, secondary_patient)
        @obs_map[obs.id] = primary_obs.id if primary_obs
      else
        obs.update(void_reason: "Merged into patient ##{primary_patient.patient_id}:0", voided: 1,
                   date_voided: Time.now, voided_by: User.current.id)
        @obs_map[obs.id] = check.id
      end
    end

    update_observations_group_id @obs_map
  end

  # method to check whether to add observations
  def check_clinician?(provider)
    User.find(provider).roles.map { |role| role['role'] }.include? 'Clinician'
  end

  # central place to void and create new observation
  def process_obervation_merging(obs, primary_patient, encounter_map, secondary_patient)
    if female_male_merge?(primary_patient,
                          secondary_patient) && secondary_female?(secondary_patient) && female_obs?(obs)
      obs.void("Merged into patient ##{primary_patient.patient_id}:0")
      return nil
    end
    primary_obs_hash = obs.attributes
    primary_obs_hash.delete('obs_id')
    primary_obs_hash.delete('uuid')
    primary_obs_hash.delete('creator')
    primary_obs_hash.delete('obs_id')
    primary_obs_hash['encounter_id'] = encounter_map[obs.encounter_id]
    primary_obs_hash['person_id'] = primary_patient.id
    primary_obs = Observation.create(primary_obs_hash)
    raise "Could not merge patient observations: #{primary_obs.errors.as_json}" unless primary_obs.errors.empty?

    obs.update(void_reason: "Merged into patient ##{primary_patient.id}:#{primary_obs.id}", voided: 1,
               date_voided: Time.now, voided_by: User.current.id)
    primary_obs
  end

  # this method updates observation table group id on the newly created observation
  def update_observations_group_id(obs_map)
    Observation.where(obs_id: obs_map.values).limit(nil).each do |obs|
      obs.update(obs_group_id: obs_map[obs.obs_group_id]) unless obs.obs_group_id
    end
  end

  # Get all encounter types that involve referring to a clinician
  def refer_to_clinician_encounter_types
    @refer_to_clinician_encounter_types ||= EncounterType.where('name = ? OR name = ?', 'HIV CLINIC CONSULTATION',
                                                                'HYPERTENSION MANAGEMENT').map(&:encounter_type_id)
  end

  # Strips off secondary_patient all encounters and blesses primary patient
  # with them
  def merge_encounters(primary_patient, secondary_patient)
    Rails.logger.debug("Merging patient encounters: #{primary_patient} <= #{secondary_patient}")
    encounter_map = {}

    # first get all encounter to be voided, create new instances from them, then void the encounter
    Encounter.where(patient_id: secondary_patient.id).each do |encounter|
      check = Encounter.find_by(
        'patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ? AND program_id = ?', primary_patient.id, encounter.encounter_type, encounter.encounter_datetime.strftime('%Y-%m-%d'), encounter.program_id
      )
      if check.blank?
        primary_encounter_hash = encounter.attributes
        primary_encounter_hash.delete('encounter_id')
        primary_encounter_hash.delete('uuid')
        primary_encounter_hash.delete('creator')
        primary_encounter_hash.delete('encounter_id')
        primary_encounter_hash['patient_id'] = primary_patient.id
        primary_encounter = Encounter.create(primary_encounter_hash)
        unless primary_encounter.errors.empty?
          raise "Could not merge patient encounters: #{primary_encounter.errors.as_json}"
        end

        encounter.update(void_reason: "Merged into patient ##{primary_patient.patient_id}:#{primary_encounter.id}",
                         voided: 1, date_voided: Time.now, voided_by: User.current.id)
        encounter_map[encounter.id] = primary_encounter.id
      else
        encounter_map[encounter.id] = check.id
        # we are trying to processes all clinician encounters observations if this visit resulted in being referred to the clinician
        # the merging needs to be smart enough to include the observartions under clinician
        if refer_to_clinician_encounter_types.include? encounter.encounter_type
          process_encounter_obs(encounter, primary_patient, secondary_patient,
                                encounter_map)
        end
        encounter.update(void_reason: "Merged into patient ##{primary_patient.patient_id}:0", voided: 1,
                         date_voided: Time.now, voided_by: User.current.id)
      end
    end

    encounter_map
  end

  # method to process encounter obs
  def process_encounter_obs(encounter, primary_patient, secondary_patient, encounter_map)
    records = encounter.observations.where(concept_id: ConceptName.find_by(name: 'Refer to ART clinician').concept_id)
    return if records.blank?

    records.each do |obs|
      primary_obs = Observation.find_by("person_id = #{primary_patient.id} AND concept_id = #{obs.concept_id} AND
        DATE(obs_datetime) = DATE('#{obs.obs_datetime.strftime('%Y-%m-%d')}')")
      next if primary_obs.blank?

      # we are trying to handle the scenario where the primary had also referred this patient to clinician
      # then we shouldn't do anything. If secondary was referred to a clinician and primary was not then merge
      unless primary_obs.value_coded != obs.value_coded && primary_obs.value_coded == ConceptName.find_by(name: 'No')
        next
      end

      result = process_obervation_merging(obs, primary_patient, encounter_map, secondary_patient)
      @obs_map[obs.id] = result.id if result
      # one needs to voide the primary
      primary_obs.update(void_reason: "Merged into patient ##{primary_patient.id}:#{result.id}", voided: 1,
                         date_voided: Time.now, voided_by: User.current.id)
      # now one needs to added all obs that occured after this choice of referral
      # these will be by the clinician/specialist
      Observation.where('encounter_id = ? AND obs_datetime >= ? AND obs_datetime <= ? person_id = ? ', encounter.id,
                        obs.obs_datetime, obs.obs_datetime.end_of_day, secondary_patient.id).each do |observation|
        if check_clinician?(observation.creator)
          result = process_obervation_merging(observation, primary_patient, encounter_map, secondary_patient)
          @obs_map[obs.id] = result.id if result
        end
      end
    end
  end

  def reassign_remote_patient_npid(patient_doc_id)
    response, status = dde_client.post('reassign_npid', { doc_id: patient_doc_id })

    raise "Failed to reassign remote patient npid: DDE Response => #{status} - #{response}" unless status == 200

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
      return nil if identifier.instance_of?(Array)

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

  def dde_enabled?
    return @dde_enabled unless @dde_enabled.nil?

    property = GlobalProperty.find_by_property('dde_enabled')
    return @dde_enabled = false unless property&.property_value

    @dde_enabled = case property.property_value
                   when /true/i then true
                   when /false/i then false
                   else raise "Invalid value for property dde_enabled: #{property.property_value}"
                   end
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

  def female_male_merge?(primary, secondary)
    primary.gender != secondary.gender
  end

  def secondary_female?(secondary)
    secondary.gender.match(/f/i)
  end

  def void_program_encounter(primary, secondary, name)
    Encounter.where(patient_id: secondary.patient_id,
                    program: Program.find_by_name(name)).each do |encounter|
                      encounter.void("Merged into patient ##{primary.patient_id}:0")
                    end
  end

  def female_concepts
    concept_ids = []
    concept_ids << concept('BREASTFEEDING').concept_id
    concept_ids << concept('BREAST FEEDING').concept_id
    concept_ids << concept('PATIENT PREGNANT').concept_id
    concept_ids << concept('Family planning method').concept_id
    concept_ids << concept('Is patient pregnant?').concept_id
    concept_ids << concept('Is patient breast feeding?').concept_id
    concept_ids << concept('Patient using family planning').concept_id
    concept_ids << concept('Method of family planning').concept_id
    concept_ids
  end

  def female_obs?(obs)
    concepts = female_concepts
    concepts.include?(obs.concept_id) || concepts.include?(obs.value_coded)
  end
end
