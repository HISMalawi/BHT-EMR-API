module HTSService::AITIntergration
  class AITIntergrationService
    attr_accessor :patients, :rest_client

    LOGGER = Logger.new(STDOUT)

    ENDPOINT = GlobalProperty.find_by_property('hts.ait.endpoint').property_value
    USERNAME = GlobalProperty.find_by_property('hts.ait.username').property_value
    PASSWORD = GlobalProperty.find_by_property('hts.ait.password').property_value

    HTC_PROGRAM = Program.find_by_name('HTC PROGRAM').id
    HIV_TESTING_ENCOUNTER = EncounterType.find_by_name('Testing')

    PARAMS = {
      :search_field => 'external_id',
      :search_column => 'client_patient_id',
      :create_new_cases => "on",
      :multipart => true
    }

    CONTACT_OBS_HEADERS = {
      'First name of contact' => 'Case Name',
      'First name of contact' => 'first_name',
      'Last name of contact' => 'last_name',
      'Gender of contact' => 'sex',
      'Age of contact' => 'age',
      'Contact phone number' => 'contact_phone_number',
      'Contact marital status' => 'marital_status',
      'Contact HIV tested' => 'hiv_status'
    }.freeze

    CONTACT_ADDITIONAL_HEADERS = %i[
      caseid parent_type contact_phone_number_verified name dob_known age_format sex_dissagregated entry_point age_in_years age_in_months age age_group dob sex
      generation close_case_date registered_by health_facility_id health_facility_name district_id district_name
      region_id region_name partner dhis2_code continue_registration import_validation site_id owner_id
    ].freeze

    HEADERS = %i[caseid index_interview_date name	first_name last_name	client_patient_id	dob_known	age_format	sex_dissagregated	marital_status	phone_number	entry_point	   consent	  consent_refusal_reason	index_comments	age_in_years	age_in_months	age	age_group	dob	index_client_category	sex	generation	close_case_date	registered_by	closed_contacts	enlisted_contacts	eligible_t_contacts	reached_contacts	tested_contacts	eligible_ait_contacts	index_client_id	health_facility_id health_facility_name district_id	district_name region_id	region_name	partner	dhis2_code	continue_registration	hiv_status	import_validation	index_entry_point
    site_id owner_id].freeze


    def initialize(patient_id)
      @patients = hts_patients_starting_from patient_id.to_i
      @rest_client = RestClient::Resource.new ENDPOINT, user: USERNAME, password: PASSWORD, verify_ssl: false
    end


    def sync
      request_is_successful = lambda { |status_code| [200, 201].include? status_code}
      return "No Patients to sync" unless patients.present? && patients.count > 1
      index = index_patients.collect { |index| create_index_row index }
      contacts = index_patients.collect { |index| create_contacts_rows index }
      index_csv = generate_csv_for index
      contact_csv = generate_csv_for contacts
      status_code = send_request 'index', index_csv
      send_request 'contact', contact_csv if request_is_successful.call status_code
      update_last_synced_patient_id patients.last.patient_id if request_is_successful.call status_code
      index.map { |obj| obj[:contacts] = contacts.select { |contact| contact['parent_external_id'] == obj[:client_patient_id] }; obj }
    end


    private

    def send_request case_type, csv
      begin
        response = rest_client.post PARAMS.merge({case_type: case_type, :file => File.new(csv, 'rb')})
      rescue RestClient::ExceptionWithResponse => e
        case e.http_code
        when 400, 401, 403
         return e.response
        else
          raise e
        end
      end
      response.code
    end

    def index_patients
      patients
    end

    def generate_csv_for rows
      f = Tempfile.create(["ait_index_#{Date.today.to_date}", ".csv"])
      CSV.open(f, 'w') do |csv|
        csv << rows.first.keys.collect { |header| header.to_s }
        rows.each { |row| csv << row.values }
      end
      f.path
    end

    def update_last_synced_patient_id patient_id
       GlobalProperty.find_by_property('hts.ait.last_synced_patient_id').update_attribute(:property_value, patient_id)
    end

    def create_index_row index
      LOGGER.info "Creating index row for #{index.id}"
      row = {}
      HEADERS.collect do |header|
        row[header] = csv_row_builder.send header, index
      end
      row
    end

    def create_contacts_rows index
        LOGGER.info "Creating contacts rows for #{index.id}"
        index_contact_list = get_index_contacts(index).collect do |contact|
          CONTACT_ADDITIONAL_HEADERS.each do |header|
            contact[header] = contact_csv_row_builder.send header, contact
            contact['parent_external_id'] = index.id
            contact['client_patient_id'] = "#{index.id.to_s}_#{contact['first_name']}_#{contact['last_name']}"
          end
          contact
        end
        index_contact_list.flatten
    end

    def get_index_contacts index
      contactList = []
      contacts_count_of(index).times do |i|
        contact = {}
        CONTACT_OBS_HEADERS.each do |header, value|
          obs = Observation.joins(concept: :concept_names)
                  .where(concept_name: {name: header}, person_id: index.id)
                  .offset(i).first
          contact[value] = get_value obs
        end
        contactList << contact
      end
      contactList
    end

    def hts_patients_starting_from patient_id
      LOGGER.info "Initializing AIT intergration service from patient id #{patient_id}"
      Patient.joins(:person, encounters: :program)
        .where(
          patient: {patient_id: patient_id..Float::INFINITY},
          encounter: { encounter_type: HIV_TESTING_ENCOUNTER},
          program: { program_id: HTC_PROGRAM }
        ).distinct.order(patient_id: :asc).limit(200)
    end

    def contacts_count_of index
      Observation.joins(concept: :concept_names)
        .where(concept_name: {name: 'First name of contact'}, person_id: index.id)
        .select(:concept_id)
        .count
    end

    def get_value obs
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