# frozen_string_literal: true

class DdeService
  require_relative './dde_service/matcher'

  class DdeError < StandardError; end

  DDE_CONFIG_PATH = 'config/application.yml'
  LOGGER = Rails.logger

  # Limit all find queries for local patients to this
  PATIENT_SEARCH_RESULTS_LIMIT = 10

  attr_accessor :program

  include ModelUtils

  def initialize(program:)
    raise InvalidParameterError, 'Program (program_id) is required' unless program

    @program = program
  end

  def self.dde_enabled?
    property = GlobalProperty.find_by_property('dde_enabled')&.property_value
    return false unless property

    case property
    when /true/i then true
    when /false/i then false
    else raise "Invalid value for property dde_enabled: #{property.property_value}"
    end
  end

  def test_connection
    response = { connection_available: false, message: 'No connection to DDE', status: 500 }
    begin
      result, status = dde_client
      response[:connection_available] = status == 200
      response[:message] = result
    rescue StandardError => e
      LOGGER.error "Failed to connect to DDE: #{e.message}"
      response[:message] = e.message
    end
    response
  end

  # Registers local OpenMRS patient in DDE
  #
  # On success patient get two identifiers under the types
  # 'DDE person document ID' and 'National id'. The
  # 'DDE person document ID' is the patient's record ID in the local
  # DDE instance and the 'National ID' is the national unique identifier
  # for the patient.
  def create_patient(patient)
    push_local_patient_to_dde(patient)
  end

  def remaining_npids
    response, status = dde_client.get("/location_npid_status?location_id=#{Location.current.id}")
    raise DdeError, "Failed to fetch remaining npids: #{status} - #{response}" unless status == 200

    response
  end

  def void_patient(patient, reason)
    raise ArgumentError, "Can't request a DDE void for a non-voided patient" unless patient.voided?
    raise ArgumentError, 'void_reason is required' if reason.blank?

    doc_id = PatientIdentifier.unscoped
                              .where(type: dde_doc_id_type, patient:)
                              .order(:date_voided)
                              .last
                              &.identifier
    return patient unless doc_id

    response, status = dde_client.delete("void_person/#{doc_id}?void_reason=#{reason}")
    raise DdeError, "Failed to void person in DDE: #{status} - #{response}" unless status == 200

    patient
  end

  # Updates patient demographics in DDE.
  #
  # Local patient is not affected in anyway by the update
  def update_patient(patient)
    dde_patient = openmrs_to_dde_patient(patient)
    response, status = dde_client.post('update_person', **dde_patient)

    raise DdeError, "Failed to update person in DDE: #{response}" unless status == 200

    patient
  end

  ##
  # Pushes a footprint for patient in current program to DDE
  def create_patient_footprint(patient, date = nil, creator_id = nil)
    LOGGER.debug("Pushing footprint to DDE for patient ##{patient.patient_id}")
    doc_id = find_patient_doc_id(patient)
    unless doc_id
      LOGGER.debug("Patient ##{patient.patient_id} is not a DDE patient")
      return
    end

    response, status = dde_client.post('update_footprint', person_uuid: doc_id,
                                                           location_id: Location.current_health_center.location_id,
                                                           program_id: program.program_id,
                                                           encounter_datetime: date || Date.tody,
                                                           user_id: creator_id || User.current.user_id)

    LOGGER.warn("Failed to push patient footprint to DDE: #{status} - #{response}") unless status == 200
  end

  ##
  # Updates local patient with demographics currently in DDE.
  def update_local_patient(patient, update_npid: false)
    doc_id = patient_doc_id(patient)
    unless doc_id
      Rails.logger.warn("No DDE doc_id found for patient ##{patient.patient_id}")
      push_local_patient_to_dde(patient)
      return patient
    end

    dde_patient = find_remote_patients_by_doc_id(doc_id).first
    unless dde_patient
      Rails.logger.warn("Couldn't find patient ##{patient.patient_id} in DDE by doc_id ##{doc_id}")
      push_local_patient_to_dde(patient)
      return patient
    end

    if update_npid
      merging_service.link_local_to_remote_patient(patient, dde_patient)
      return patient
    end

    person_service.update_person(patient.person, dde_patient_to_local_person(dde_patient))
    patient
  end

  # Import patients from DDE using doc id
  def import_patients_by_doc_id(doc_id)
    doc_id_type = patient_identifier_type('DDE person document id')
    locals = patient_service.find_patients_by_identifier(doc_id, doc_id_type).limit(PATIENT_SEARCH_RESULTS_LIMIT)
    remotes = find_remote_patients_by_doc_id(doc_id)

    import_remote_patient(locals, remotes)
  end

  # Imports patients from DDE to the local database
  def import_patients_by_npid(npid)
    doc_id_type = patient_identifier_type('National id')
    locals = patient_service.find_patients_by_identifier(npid, doc_id_type).limit(PATIENT_SEARCH_RESULTS_LIMIT)
    remotes = find_remote_patients_by_npid(npid)

    import_remote_patient(locals, remotes)
  end

  # Similar to import_patients_by_npid but uses name and gender instead of npid
  def import_patients_by_name_and_gender(given_name, family_name, gender)
    locals = patient_service.find_patients_by_name_and_gender(given_name, nil, family_name,
                                                              gender).limit(PATIENT_SEARCH_RESULTS_LIMIT)
    remotes = find_remote_patients_by_name_and_gender(given_name, family_name, gender)

    import_remote_patient(locals, remotes)
  end

  def find_patients_by_npid(npid)
    remotes = []
    locals = patient_service.find_patients_by_npid(npid).limit(PATIENT_SEARCH_RESULTS_LIMIT)
    begin
      remotes = find_remote_patients_by_npid(npid)
    rescue StandardError => e 
      Rails.logger.info "Caught an exception : #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    package_patients(locals, remotes, auto_push_singular_local: true)
  end

  def find_patients_by_name_and_gender(given_name, family_name, gender)
    remotes = []
    locals = patient_service.find_patients_by_name_and_gender(given_name, nil, family_name,
                                                              gender).limit(PATIENT_SEARCH_RESULTS_LIMIT)
    begin
      remotes = find_remote_patients_by_name_and_gender(given_name, family_name, gender)
    rescue StandardError => e
      Rails.logger.info "Caught an exception : #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    package_patients(locals, remotes)
  end

  def find_patient_updates(local_patient_id)
    dde_doc_id_type = PatientIdentifierType.where(name: 'DDE Person Document ID')
    doc_id = PatientIdentifier.find_by(patient_id: local_patient_id, type: dde_doc_id_type)
                              &.identifier
    return nil unless doc_id

    remote_patient = find_remote_patients_by_doc_id(doc_id).first
    return nil unless remote_patient

    Matcher.find_differences(Person.find(local_patient_id), remote_patient)
  rescue DdeError => e
    Rails.logger.warn("Check for DDE patient updates failed: #{e.message}")
    nil
  end

  # Matches patients using a bunch of demographics
  def match_patients_by_demographics(family_name:, given_name:, birthdate:,
                                     gender:, home_district:, home_traditional_authority:,
                                     home_village:, birthdate_estimated: 0)
    response, status = dde_client.post(
      'search/people', family_name:,
                       given_name:,
                       gender:,
                       birthdate:,
                       birthdate_estimated: !birthdate_estimated.zero?,
                       attributes: {
                         home_district:,
                         home_traditional_authority:,
                         home_village:
                       }
    )

    raise DdeError, "DDE patient search failed: #{status} - #{response}" unless status == 200

    response.collect do |match|
      doc_id = match['person']['id']
      patient = patient_service.find_patients_by_identifier(
        doc_id, patient_identifier_type('DDE person document id')
      ).first
      match['person']['patient_id'] = patient&.id
      match
    end
  end

  # Trigger a merge of patients in DDE
  def merge_patients(primary_patients_ids, secondary_patient_ids)
    merging_service.merge_patients(primary_patients_ids, secondary_patient_ids)
  end

  def reassign_patient_npid(patient_ids)
    patient_id = patient_ids['patient_id']
    doc_id = patient_ids['doc_id']

    raise InvalidParameterError, 'patient_id and/or doc_id required' if patient_id.blank? && doc_id.blank?

    if doc_id.blank?
      # Only have patient id thus we have patient locally only
      return push_local_patient_to_dde(Patient.find(patient_ids['patient_id']))
    end

    # NOTE: Fail patient retrieval as early as possible before making any
    # changes to DDE (ie if patient_id does not exist)
    patient = patient_id.blank? ? nil : Patient.find(patient_id)

    # We have a doc_id thus we can re-assign npid in DDE
    # Check if person if available in DDE if not add person using doc_id
    response, status = dde_client.post('search_by_doc_id', doc_id:)
    if !response.blank? && status.to_i == 200
      response, status = dde_client.post('reassign_npid', doc_id:)
    elsif response.blank? && status.to_i == 200
      return push_local_patient_to_dde(Patient.find(patient_ids['patient_id']))
    end

    unless status == 200 && !response.empty?
      # The DDE's reassign_npid end point responds with a 200 - OK but returns
      # an empty object when patient with given doc_id is not found.
      raise DdeError, "Failed to reassign npid: DDE Response => #{status} - #{response}"
    end

    return save_remote_patient(response) unless patient

    merging_service.link_local_to_remote_patient(patient, response)
  end

  # Convert a DDE person to an openmrs person.
  #
  # NOTE: This creates a person on the database.
  def save_remote_patient(remote_patient)
    LOGGER.debug "Converting DDE person to openmrs: #{remote_patient}"
    params = dde_patient_to_local_person(remote_patient)

    Person.transaction do
      person = person_service.create_person(params)
      person_service.create_person_name(person, params)
      person_service.create_person_address(person, params)
      person_service.create_person_attributes(person, params)

      patient = Patient.create(patient_id: person.id)
      merging_service.link_local_to_remote_patient(patient, remote_patient)
    end
  end

  ##
  # Converts a dde_patient object into an object that can be passed to the person_service
  # to create or update a person.
  def dde_patient_to_local_person(dde_patient)
    attributes = dde_patient.fetch('attributes')

    ActiveSupport::HashWithIndifferentAccess.new(
      birthdate: dde_patient.fetch('birthdate'),
      birthdate_estimated: dde_patient.fetch('birthdate_estimated'),
      gender: dde_patient.fetch('gender'),
      given_name: dde_patient.fetch('given_name'),
      family_name: dde_patient.fetch('family_name'),
      middle_name: dde_patient.fetch('middle_name'),
      home_village: attributes.fetch('home_village'),
      home_traditional_authority: attributes.fetch('home_traditional_authority'),
      home_district: attributes.fetch('home_district'),
      current_village: attributes.fetch('current_village'),
      current_traditional_authority: attributes.fetch('current_traditional_authority'),
      current_district: attributes.fetch('current_district')
      # cell_phone_number: attributes.fetch('cellphone_number'),
      # occupation: attributes.fetch('occupation')
    )
  end

  private

  def find_remote_patients_by_npid(npid)
    response, _status = dde_client.post('search_by_npid', npid:)
    raise DdeError, "Patient search by npid failed: DDE Response => #{response}" unless response.instance_of?(Array)

    response
  end

  def find_remote_patients_by_name_and_gender(given_name, family_name, gender)
    response, _status = dde_client.post('search_by_name_and_gender', given_name:,
                                                                     family_name:,
                                                                     gender:)
    unless response.instance_of?(Array)
      raise DdeError, "Patient search by name and gender failed: DDE Response => #{response}"
    end

    response
  end

  def find_remote_patients_by_doc_id(doc_id)
    Rails.logger.info("Searching for DDE patient by doc_id ##{doc_id}")
    response, _status = dde_client.post('search_by_doc_id', doc_id:)
    raise DdeError, "Patient search by doc_id failed: DDE Response => #{response}" unless response.instance_of?(Array)

    response
  end

  def find_patient_doc_id(patient)
    patient.patient_identifiers.where(type: dde_doc_id_type).first
  end

  # Resolves local and remote patients and post processes the remote
  # patients to take on a structure similar to that of local
  # patients.
  def package_patients(local_patients, remote_patients, auto_push_singular_local: false)
    patients = resolve_patients(local_patients:,
                                remote_patients:,
                                auto_push_singular_local:)

    # In some cases we may have remote patients that were previously imported but
    # whose NPID has changed, we need to find and resolve these local patients.
    unresolved_patients = find_patients_by_doc_id(patients[:remotes].collect do |remote_patient|
                                                    remote_patient['doc_id']
                                                  end)
    if unresolved_patients.empty?
      return { locals: patients[:locals],
               remotes: patients[:remotes].collect { |patient| localise_remote_patient(patient) }
             }
    end

    additional_patients = resolve_patients(local_patients: unresolved_patients, remote_patients: patients[:remotes])

    {
      locals: patients[:locals] + additional_patients[:locals],
      remotes: additional_patients[:remotes].collect { |patient| localise_remote_patient(patient) }
    }
  end

  # Locally saves the first unresolved remote patient.
  #
  # Method internally calls resolve_patients on the passed arguments then
  # attempts to save the first unresolved patient in the local database.
  #
  # Returns: The imported patient (or nil if no local and remote patients are
  #          present).
  def import_remote_patient(local_patients, remote_patients)
    patients = resolve_patients(local_patients:, remote_patients:)

    return patients[:locals].first if patients[:remotes].empty?

    save_remote_patient(patients[:remotes].first)
  end

  # Filters out @{param remote_patients} that exist in @{param local_patients}.
  #
  # Returns a hash with all resolved and unresolved remote patients:
  #
  #   { resolved: [..,], locals: [...], remotes: [...] }
  #
  # NOTE: All resolved patients are available in the local database
  def resolve_patients(local_patients:, remote_patients:, auto_push_singular_local: false)
    remote_patients = remote_patients.dup # Will be modifying this copy

    # Match all locals to remotes, popping out the matching patients from
    # the list of remotes. The remaining remotes are considered unresolved
    # remotes.
    resolved_patients = local_patients.each_with_object([]) do |local_patient, resolved_patients|
      # Local patient present on remote?
      remote_patient = remote_patients.detect do |patient|
        same_patient?(local_patient:, remote_patient: patient)
      end

      remote_patients.delete(remote_patient) if remote_patient

      resolved_patients << local_patient
    end

    if resolved_patients.empty? && (local_patients.empty? && remote_patients.size == 1)
      # HACK: Frontenders requested that if only a single patient exists
      # remotely and locally none exists, the remote patient should be
      # imported.
      local_patient = find_patients_by_doc_id(remote_patients[0]['doc_id']).first
      resolved_patients = [local_patient || save_remote_patient(remote_patients[0])]
      remote_patients = []
    elsif auto_push_singular_local && resolved_patients.size == 1\
         && remote_patients.empty? && local_only_patient?(resolved_patients.first)
      # ANOTHER HACK: Push local only patient to DDE
      resolved_patients = [push_local_patient_to_dde(resolved_patients[0])]
    else
      resolved_patients = local_patients
    end
    { locals: resolved_patients, remotes: remote_patients }
  end

  # Checks if patient only exists on local database
  def local_only_patient?(patient)
    !(patient.patient_identifiers.where(type: patient_identifier_type('National id')).exists?\
      && patient.patient_identifiers.where(type: patient_identifier_type('DDE person document id')).exists?)
  end

  # Matches local and remote patient
  def same_patient?(local_patient:, remote_patient:)
    PatientIdentifier.where(patient: local_patient, type: dde_doc_id_type).any? do |doc_id|
      doc_id.identifier == remote_patient['doc_id']
    end
  end

  # Saves local patient to DDE and links the two using the IDs
  # generated by DDE.
  def push_local_patient_to_dde(patient)
    Rails.logger.info("Pushing local patient ##{patient.patient_id} to DDE")
    response, status = dde_client.post('add_person', **openmrs_to_dde_patient(patient))

    if status == 422
      error = UnprocessableEntityError.new("Failed to create patient in DDE: #{response.to_json}")
      error.add_entity(patient)
      raise error
    end

    raise response.to_json if status != 200

    merging_service.link_local_to_remote_patient(patient, response)
  end

  # Converts a remote patient coming from DDE into a structure similar
  # to that of a local patient
  def localise_remote_patient(patient)
    Patient.new(
      patient_identifiers: localise_remote_patient_identifiers(patient),
      person: Person.new(
        names: localise_remote_patient_names(patient),
        addresses: localise_remote_patient_addresses(patient),
        birthdate: patient['birthdate'],
        birthdate_estimated: patient['birthdate_estimated'],
        gender: patient['gender']
      )
    )
  end

  def localise_remote_patient_identifiers(remote_patient)
    [PatientIdentifier.new(identifier: remote_patient['npid'],
                           type: patient_identifier_type('National ID')),
     PatientIdentifier.new(identifier: remote_patient['doc_id'],
                           type: patient_identifier_type('DDE Person Document ID'))]
  end

  def localise_remote_patient_names(remote_patient)
    [PersonName.new(given_name: remote_patient['given_name'],
                    family_name: remote_patient['family_name'],
                    middle_name: remote_patient['middle_name'])]
  end

  def localise_remote_patient_addresses(remote_patient)
    address = PersonAddress.new
    address.home_village = remote_patient['attributes']['home_village']
    address.home_traditional_authority = remote_patient['attributes']['home_traditional_authority']
    address.home_district = remote_patient['attributes']['home_district']
    address.current_village = remote_patient['attributes']['current_village']
    address.current_traditional_authority = remote_patient['attributes']['current_traditional_authority']
    address.current_district = remote_patient['attributes']['current_district']
    [address]
  end

  def dde_client
    client = DdeClient.new

    connection = dde_connections[program.id]

    dde_connections[program.id] = if connection
                                    client.restore_connection(connection)
                                  else
                                    client.connect(**dde_config)
                                  end

    client
  end

  # Loads a dde client into the dde_clients_cache for the
  def dde_config
    main_config = YAML.load_file(DDE_CONFIG_PATH)['dde']
    raise 'No configuration for DDE found' unless main_config

    program_config = main_config[program.name.downcase]
    raise "No DDE config for program #{program.name} found" unless program_config

    {
      url: main_config['url'],
      username: program_config['username'],
      password: program_config['password']
    }
  end

  # Converts an openmrs patient structure to a DDE person structure
  def openmrs_to_dde_patient(patient)
    LOGGER.debug "Converting OpenMRS person to dde_patient: #{patient}"
    person = patient.person

    person_name = person.names[0]
    person_address = person.addresses[0]
    person_attributes = filter_person_attributes(person.person_attributes)

    dde_patient = HashWithIndifferentAccess.new(
      given_name: person_name.given_name,
      family_name: person_name.family_name,
      gender: person.gender&.first,
      birthdate: person.birthdate,
      birthdate_estimated: person.birthdate_estimated, # Convert to bool?
      attributes: {
        current_district: person_address&.state_province,
        current_traditional_authority: person_address&.township_division,
        current_village: person_address&.city_village,
        home_district: person_address&.address2,
        home_village: person_address&.neighborhood_cell,
        home_traditional_authority: person_address&.county_district,
        occupation: person_attributes ? person_attributes[:occupation] : nil
      }
    )

    doc_id = patient.patient_identifiers.where(type: patient_identifier_type('DDE person document id')).first
    dde_patient[:doc_id] = doc_id.identifier if doc_id

    LOGGER.debug "Converted openmrs person to dde_patient: #{dde_patient}"
    dde_patient
  end

  def filter_person_attributes(person_attributes)
    return nil unless person_attributes

    person_attributes.each_with_object({}) do |attr, filtered|
      case attr.type.name.downcase.gsub(/\s+/, '_')
      when 'cell_phone_number'
        filtered[:cell_phone_number] = attr.value
      when 'occupation'
        filtered[:occupation] = attr.value
      when 'birthplace'
        filtered[:home_district] = attr.value
      when 'home_village'
        filtered[:home_village] = attr.value
      when 'ancestral_traditional_authority'
        filtered[:home_traditional_authority] = attr.value
      end
    end
  end

  def patient_doc_id(patient)
    PatientIdentifier
      .joins(:type)
      .merge(PatientIdentifierType.where(name: 'DDE person document id'))
      .where(patient:)
      .first
      &.identifier
  end

  def dde_doc_id_type
    PatientIdentifierType.find_by_name('DDE Person document ID')
  end

  def find_patients_by_doc_id(doc_ids)
    identifiers = PatientIdentifier.joins(:type)
                                   .merge(PatientIdentifierType.where(name: 'DDE Person Document ID'))
                                   .where(identifier: doc_ids)
    Patient.joins(:patient_identifiers).merge(identifiers).distinct
  end

  def person_service
    PersonService.new
  end

  def patient_service
    PatientService.new
  end

  def merging_service
    DdeMergingService.new(self, -> { dde_client })
  end

  # A cache for all connections to dde (indexed by program id)
  def dde_connections
    @@dde_connections ||= {}
  end
end
