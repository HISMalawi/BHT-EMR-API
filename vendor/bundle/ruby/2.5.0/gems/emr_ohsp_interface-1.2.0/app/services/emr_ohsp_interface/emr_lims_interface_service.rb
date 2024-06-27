# frozen_string_literal: true

require 'emr_ohsp_interface/version'
module EmrOhspInterface
  module EmrLimsInterfaceService
    class << self
      require 'csv'
      require 'rest-client'

      def initialize
        @mysql_connection_pool = {}
      end
      ######################################### start creation of lab test in lims  #####################################################
      def settings
        file = File.read(Rails.root.join('db', 'lims_metadata', 'lims_map.json'))
        JSON.parse(file)
      end

      def get_patient_number
        get_patient_id = query "SELECT id FROM iblis.patients order by id desc limit 1;"

        get_patient_id.each do |x|
         return patient_number = x['id']
        end
        


      end

      def check_patient_number(patient_id)
          get_patient_id = query "SELECT patient_number FROM patients WHERE `external_patient_number` ='#{patient_id}'; "

          get_patient_id.each do |x|
            return patient_number = x['patient_number']
          end

      end

      def filterpatient_number(data)
        patient_number = 0
        data.each do |x|
          patient_number = x['patient_identify']
        end
        patient_number
      end

      def get_patient_dentifier(patient_id)
        patient_dentifier =PatientIdentifier.where('patient_id= ? AND identifier_type = ?', patient_id,3)[0]
        patient_dentifier[:identifier]
      end
      def create_lab_order(lab_details, clinician_id)
        external_patient_number = get_patient_dentifier(lab_details[0][:patient_id])
        patient_number = check_patient_number(external_patient_number)
        time = Time.new
        date = time.strftime('%Y-%m-%d %H:%M:%S')
        lab_details.map do |order_params|
          if patient_number.blank?
            patient_number = get_patient_number() + 1

            person_data = Person.where('person_id= ?', order_params[:patient_id])[0]
            address_data = PersonAddress.where('person_id= ?', order_params[:patient_id])[0]
            name_data = PersonName.where('person_id= ?', order_params[:patient_id])[0]

            gender = person_data[:gender].match(/f/i) ? 1 : (person_data[:gender].match(/m/i) ? 0 : 2)
            create_patient(
              name_data[:given_name],
              name_data[:family_name],
              clinician_id[0][:requesting_clinician_id],
              address_data[:address1],
              gender,
              person_data[:birthdate],
              person_data[:birthdate_estimated],
              external_patient_number,
              patient_number,
              date
            )
          end
          create_visit(patient_number, date)
          create_specimens(
            clinician_id[0][:requesting_clinician_id],
            order_params[:specimen][:name],
            order_params[:accession_number]
          )
          specimen_id = get_specimen_id
          create_unsync_orders(date, specimen_id)

          create_test(specimen_id, order_params[:requesting_clinician], order_params[:tests][0][:name])
        end
      end

      def create_patient(
        firstname, surname,
        user_id, address,
        gender, dob,
        dob_estimated, external_patient_number,
        patient_number, date
      )
        query(
          "INSERT INTO `patients` (`name`, `first_name_code`, `last_name_code`, `created_by`, `address`, `gender`, `patient_number`, `dob`, `dob_estimated`, `external_patient_number`, `created_at`, `updated_at`)
          VALUES ('#{firstname} #{surname}', SOUNDEX('#{firstname}'), SOUNDEX('#{surname}'), #{user_id}, '#{address}',#{gender},'#{patient_number}', '#{dob}', '#{dob_estimated}', '#{external_patient_number}', '#{date}', '#{date}')"
        )
      end

      def create_visit(patient_number, date)
        query "INSERT INTO `visits` (`patient_id`, `visit_type`, `ward_or_location`, `created_at`, `updated_at`)
                VALUES ('#{patient_number}', 'Out Patient', 'EM OPD', '#{date}', '#{date}')"
      end

      def create_specimens(user_id, specimen_type, tracking_number)
        specimen_type_id = settings['lims_specimen_map'][specimen_type.to_s]
        accession_number = new_accession_number
        # prepare_next_tracking_number()
        # tracking_number = create_local_tracking_number()
        query(" INSERT INTO `specimens` (`specimen_type_id`, `accepted_by`, `priority`, `accession_number`, `tracking_number`)
        VALUES ('#{specimen_type_id}', '#{user_id}', 'Stat', '#{accession_number}', '#{tracking_number}')")
      end

      def create_unsync_orders(date, specimen_id)
        query(" INSERT INTO `unsync_orders` (`specimen_id`, `data_not_synced`, `data_level`, `sync_status`, `updated_by_name`, `updated_by_id`, `created_at`, `updated_at`)
        VALUES ('#{specimen_id}', 'new order', 'specimen', 'not-synced', 'kBLIS Administrator', '1', '#{date}', '#{date}')")
      end

      def create_test(specimen_id, requested_by, test_type)
        visit_id = get_visit_id
        test_type_id = settings['lims_test_type_map'][test_type.to_s]
        query("INSERT INTO `tests` (`visit_id`, `test_type_id`, `specimen_id`, `test_status_id`, `not_done_reasons`, `person_talked_to_for_not_done`, `created_by`, `requested_by`)
         VALUES ('#{visit_id}', '#{test_type_id}', '#{specimen_id}', '2', '0', '0', 1, '#{requested_by}')")
      end

      def new_accession_number
        # Generate the next accession number for specimen registration
        @mutex = Mutex.new if @mutex.blank?
        @mutex.lock
        max_acc_num = 0
        return_value = nil
        sentinel = 99_999_999

        settings = YAML.load_file("#{Rails.root}/config/application.yml")[Rails.env]
        code = settings['facility_code']
        year = Date.today.year.to_s[2..3]

        record = get_last_accession_number

        unless record.blank?
          max_acc_num = record[5..20].match(/\d+/)[0].to_i # first 5 chars are for facility code and 2 digit year
        end

        if max_acc_num < sentinel
          max_acc_num += 1
        else
          max_acc_num = 1
        end

        max_acc_num = max_acc_num.to_s.rjust(8, '0')
        return_value = "#{code}#{year}#{max_acc_num}"
        @mutex.unlock

        return_value
      end

      def get_last_accession_number
        data = query('SELECT * FROM specimens WHERE accession_number IS NOT NULL ORDER BY id DESC LIMIT 1')
        data.each do |x|
          return last_accession_number = x['accession_number']
        end
      end

      def get_specimen_id
        data = query('SELECT * FROM specimens WHERE accession_number IS NOT NULL ORDER BY id DESC LIMIT 1')
        data.each do |x|
          return specimen_id = x['id']
        end
      end

      def get_visit_id
        data = query('SELECT * FROM visits WHERE id IS NOT NULL ORDER BY id DESC LIMIT 1')
        data.each do |x|
          return specimen_id = x['id']
        end
      end

      def prepare_next_tracking_number
        file = JSON.parse(File.read("#{Rails.root}/public/tracker.json"))
        todate = Time.now.strftime('%Y%m%d')

        counter = file[todate]
        counter = counter.to_i + 1
        fi = {}
        fi[todate] = counter
        File.open("#{Rails.root}/public/tracker.json", 'w') do |f|
          f.write(fi.to_json)
        end
      end

      ###### lims tracking number ###############
      def create_local_tracking_number
        configs = YAML.load_file "#{Rails.root}/config/application.yml"
        site_code = configs['facility_code']
        file = JSON.parse(File.read("#{Rails.root}/public/tracker.json"))
        todate = Time.now.strftime('%Y%m%d')
        year = Time.now.strftime('%Y%m%d').to_s.slice(2..3)
        month = Time.now.strftime('%m')
        day = Time.now.strftime('%d')

        key = file.keys

        if todate > key[0]

          fi = {}
          fi[todate] = 1
          File.open("#{Rails.root}/public/tracker.json", 'w') do |f|
            f.write(fi.to_json)
          end

          value = '001'
          tracking_number = "X#{site_code}#{year}#{get_month(month)}#{get_day(day)}#{value}"

        else
          counter = file[todate]

          value = if counter.to_s.length == 1
                    '00' + counter.to_s
                  elsif counter.to_s.length == 2
                    '0' + counter.to_s
                  else
                    begin
                        counter.to_s
                    rescue StandardError
                      '001'
                      end
                  end

          tracking_number = "X#{site_code}#{year}#{get_month(month)}#{get_day(day)}#{value}"

        end
        tracking_number
      end

      def get_month(month)
        case month

        when '01'
          '1'
        when '02'
          '2'
        when '03'
          '3'
        when '04'
          '4'
        when '05'
          '5'
        when '06'
          '6'
        when '07'
          '7'
        when '08'
          '8'
        when '09'
          '9'
        when '10'
          'A'
        when '11'
          'B'
        when '12'
          'C'
          end
      end

      def get_day(day)
        case day

        when '01'
          '1'
        when '02'
          '2'
        when '03'
          '3'
        when '04'
          '4'
        when '05'
          '5'
        when '06'
          '6'
        when '07'
          '7'
        when '08'
          '8'
        when '09'
          '9'
        when '10'
          'A'
        when '11'
          'B'
        when '12'
          'C'
        when '13'
          'E'
        when '14'
          'F'
        when '15'
          'G'
        when '16'
          'H'
        when '17'
          'Y'
        when '18'
          'J'
        when '19'
          'K'
        when '20'
          'Z'
        when '21'
          'M'
        when '22'
          'N'
        when '23'
          'O'
        when '24'
          'P'
        when '25'
          'Q'
        when '26'
          'R'
        when '27'
          'S'
        when '28'
          'T'
        when '29'
          'V'
        when '30'
          'W'
        when '31'
          'X'
          end
      end
############################################# end creation of lab test in lims  #####################################################

############## get results from lims ###############

def get_lims_test_results(tracking_number,patient_id)
  external_patient_number = get_patient_dentifier(patient_id)
  data = query("
    SELECT
    visits.ward_or_location, specimens.accession_number,
    tests.created_by, tests.verified_by,
    tests.time_completed,tests.requested_by,tests.interpretation,
    tests.time_created         as         tests_time_created,       
    test_types.name            as    test_types_name,          
    test_categories.name       as   test_categories_name,     
    tests.time_verified        as    tests_time_verified,      
    users.name                 as  users_name,               
    specimen_types.name        as        specimen_types_name,      
    specimen_statuses.name     as              specimen_statuses_name,   
    test_results.result        as          test_results_result,      
    test_results.device_name   as              test_results_device_name, 
    measures.name              as  measures_name,            
    measures.unit             as  measures_unit,            
    measure_ranges.range_lower as measure_ranges_range_lower,
    measure_ranges.range_upper   as  measure_ranges_range_upper                                      
    FROM iblis.patients 
    inner join iblis.visits on `visits`.`patient_id` = `patients`.`patient_number` 
    inner join iblis.tests on `tests`.`visit_id` = `visits`.`id` 
    inner join iblis.test_types on `test_types`.`id` = `tests`.`test_type_id`
    inner join iblis.test_categories on `test_categories`.`id` = `test_types`.`test_category_id`
    inner join iblis.users on `users`.`id` = `tests`.`tested_by`
    inner join iblis.specimens on `specimens`.`id` = `tests`.`specimen_id`
    inner join iblis.specimen_types on `specimen_types`.`id` = `specimens`.`specimen_type_id`
    inner join iblis.specimen_statuses on `specimen_statuses`.`id` = `specimens`.`specimen_status_id`
    right join iblis.test_results on `test_results`.`test_id` = `tests`.`id`
    right join iblis.measures on `measures`.`id` = `test_results`.`measure_id`
    right join iblis.measure_ranges on `measure_ranges`.`measure_id` = `measures`.`id`
    where `patients`.`deleted_at` is null and `specimens`.`tracking_number` = '#{tracking_number}' and  `patients`.`external_patient_number` = '#{external_patient_number}' and `measure_ranges`.`deleted_at` 
    is null group by(`measure_ranges`.`measure_id`) order by time_completed asc ;
    ")
    data
end
def get_user_details(user_id)
  data = query("SELECT * FROM iblis.users where id = #{user_id};")
  data
end
############################################# start connection to lims database  ######################################################
      def query(sql)
        Rails.logger.debug(sql.to_s)
        result = mysql.query(sql)
     end

      def mysql
        # self.initialize
        return mysql_connection if mysql_connection

        connection = Mysql2::Client.new(host: settings['headers']['host'],
                                        username: settings['headers']['username'],
                                        password: settings['headers']['password'],
                                        port: settings['headers']['port'],
                                        database: settings['headers']['database'],
                                        reconnect: true)
        self.mysql_connection = connection
      end

      def mysql_connection=(connection)
        @mysql_connection_pool = connection
      end

      def mysql_connection
        @mysql_connection_pool
      end
############################################# end connection to lims database  ######################################################
    end
  end
end
