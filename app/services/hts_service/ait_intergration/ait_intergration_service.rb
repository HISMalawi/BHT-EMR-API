module HTSService::AITIntergration
  class AITIntergrationService
    attr_accessor :patients, :rest_client

    LOGGER = Logger.new(STDOUT)

    AIT_CONFIG = YAML.load_file("#{Rails.root}/config/ait.yml")

    HTC_PROGRAM = Program.find_by_name('HTC PROGRAM').id
    HIV_TESTING_ENCOUNTER = EncounterType.find_by_name('Testing')

    PARAMS = {
      :search_field => 'external_id',
      :search_column => 'client_patient_id',
      :create_new_cases => 'on',
      :multipart => true,
    }

    CONTACT_ADDITIONAL_HEADERS = %i[
      first_name last_name sex age contact_phone_number marital_status new_hiv_status case_id caseid parent_type contact_phone_number_verified name dob_known age_format sex_dissagregated entry_point age_in_years age_in_months age age_group dob sex
      generation close_case_date registered_by health_facility_id health_facility_name district_id district_name
      region_id region_name partner dhis2_code continue_registration physical_address import_validation site_id owner_id appointment_date referral_type appointment_location hiv_test_date index_entry_point
      consent_to_contact select_recommended_mode_of_notification traditional_authority village ipv_status relationship_with_index_adult
    ].freeze

    HEADERS = %i[
      caseid index_interview_date name first_name last_name client_patient_id dob_known age_format sex_dissagregated marital_status phone_number entry_point consent consent_refusal_reason index_comments age_in_years age_in_months age age_group dob index_client_category sex generation close_case_date registered_by closed_contacts enlisted_contacts eligible_t_contacts reached_contacts tested_contacts eligible_ait_contacts index_client_id health_facility_id health_facility_name district_id district_name region_id region_name partner dhis2_code continue_registration hiv_status import_validation index_entry_point site_id owner_id
    ].freeze

    def initialize(patient_id)
      raise 'AIT config not found or not properly set, please refer to the ait.yml.example' unless !AIT_CONFIG['endpoint'].empty?

      failed_ids = GlobalProperty.find_by_property('hts.ait.failed_queue')&.property_value&.split(',') || []

      @patients = hts_patients_starting_from patient_id.to_i
      @failed = Patient.where(patient_id: failed_ids).order(patient_id: :asc) if failed_ids.present?

      @patients = @patients + @failed if @failed.present?

      @rest_client = RestClient::Resource.new AIT_CONFIG['endpoint'], user: AIT_CONFIG['username'], password: AIT_CONFIG['password'], verify_ssl: false
    end

    def sync
      begin      
        request_is_successful = lambda { |status_code| [200, 201].include? status_code }
        return 'No Patients to sync' unless patients.present?
        
        index = index_patients.collect { |i| create_index_row i }
        contacts = index_patients.collect { |i| create_contacts_rows i }.flatten
        index_csv = generate_csv_for index
        contact_csv = generate_csv_for contacts
        status_code = send_request 'index', index_csv
        send_request 'contact', contact_csv if request_is_successful.call status_code
        update_last_synced_patient_id patients.last.patient_id if request_is_successful.call status_code
        remove_from_failed_queue
        index.map { |obj| obj[:contacts] = contacts.select { |contact| contact['parent_external_id'] == obj[:client_patient_id] }; obj }
      rescue StandardError => e
        LOGGER.error e.message
        LOGGER.info "Adding patients #{@patients.map(&:patient_id)} to the failed queue"
        add_to_failed_queue
        raise e
      end
    end

    private

    def add_to_failed_queue
      patient_ids = @patients.map(&:patient_id)

      failed_queue = GlobalProperty.where(property: 'hts.ait.failed_queue')

      queue_ids = failed_queue.pluck(:property_value)
      
      failed_queue.update_all(property_value: (queue_ids + patient_ids)&.uniq&.join(','))
    end

    def remove_from_failed_queue
      failed_queue = GlobalProperty.find_by_property('hts.ait.failed_queue')
      return unless failed_queue.present?
      failed_queue.update_attribute(:property_value, failed_queue.property_value.split(',').reject { |id| @patients.map(&:patient_id).include? id.to_i }.join(','))
    end

    def send_request(case_type, csv)
      begin
        response = rest_client.post PARAMS.merge({ case_type: case_type, :file => File.new(csv, "rb") })
      rescue RestClient::ExceptionWithResponse => e
        raise e.response
      end
      response.code
    end

    def index_patients
      patients
    end

    def generate_csv_for(rows)
      return unless rows.present?

      f = Tempfile.create(["ait_index_#{Date.today.to_date}", '.csv'])
      CSV.open(f, 'w') do |csv|
        csv << rows.first.keys.collect { |header| header.to_s }
        rows.each { |row| csv << row.values }
      end
      f.path
    end

    def update_last_synced_patient_id(patient_id)
      property = GlobalProperty.find_by_property('hts.ait.last_synced_patient_id')
      GlobalProperty.create(property: 'hts.ait.last_synced_patient_id', property_value: patient_id) unless property.present?
      property.update_attribute(:property_value, patient_id)
    end

    def create_index_row(index)
      LOGGER.info "Creating index row for #{index.id}"
      row = {}
      HEADERS.collect do |header|
        row[header] = csv_row_builder.send header, index
      end
      row
    end

    def create_contacts_rows(patient)
      LOGGER.info "Creating contacts rows for #{patient.id}"
      rows = []
      get_index_contacts(patient).each_with_index do |contact, index|
        row = {}
        CONTACT_ADDITIONAL_HEADERS.each do |header|
          row[header] = contact_csv_row_builder.send header, contact, index rescue nil

          row['parent_external_id'] = patient.id
          row['client_patient_id'] = "#{patient.id}_#{contact['Firstnames of contact']}#{contact['First name of contact']}_#{contact['Last name of contact']}#{contact['Lastname of contact']}"
          row['contact_id'] = row['client_patient_id']
          row['index_interview_date'] = patient.encounters.last.encounter_datetime&.to_date
        end
        rows << row
      end
      rows
    end

    def get_index_contacts(index)
      contacts = []
      Observation
        .where(person_id: index.patient_id, concept_id: ConceptName.find_by_name('First name of contact').concept_id)
        .select(:obs_group_id)
        .distinct
        .each do |obs|
          obj = {}
          obs = Observation.where(obs_group_id: obs.obs_group_id).order(obs_datetime: :desc)
          obs.each do |o|
            obj[ConceptName.find_by_concept_id(o.concept_id).name] = o&.answer_string&.strip
          end
          contacts << obj
        end
      contacts.uniq
    end

    def hts_patients_starting_from(patient_id)
      LOGGER.info "Initializing AIT intergration service from patient id #{patient_id}"
      Patient.joins(:person, encounters: [:observations, :program])
        .where('person.person_id >= ?', patient_id)
        .where(
          obs: { concept_id: ConceptName.find_by_name('HIV status').concept_id, value_coded: ConceptName.find_by_name('Positive').concept_id },
          encounter: { encounter_type: HIV_TESTING_ENCOUNTER },
          program: { program_id: HTC_PROGRAM },
        )
        .distinct.order(patient_id: :asc).limit(200)
    end

    def get_value(obs)
      return nil if obs.nil?
      return obs.answer_string.strip unless obs.answer_string.empty?
      return obs.value_numeric.strip unless obs.value_numeric.empty?
      return obs.value_coded.strip unless obs.value_coded.empty?
    end

    def contact_csv_row_builder
      HTSService::AITIntergration::ContactCsvRowBuilder.new
    end

    def csv_row_builder
      HTSService::AITIntergration::CsvRowBuilder.new
    end
  end
end
