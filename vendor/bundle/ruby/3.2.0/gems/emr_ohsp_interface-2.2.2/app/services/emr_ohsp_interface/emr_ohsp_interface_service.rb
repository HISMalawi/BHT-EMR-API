require "emr_ohsp_interface/version"

module EmrOhspInterface
  module EmrOhspInterfaceService
    class << self
      require 'csv'
      require 'rest-client'
      require 'json'
      def settings
        file = File.read(Rails.root.join("db","idsr_metadata","idsr_ohsp_settings.json"))
        config = JSON.parse(file)
      end

      def server_config
        config =YAML.load_file("#{Rails.root}/config/application.yml")
      end

      def get_ohsp_facility_id
        file = File.open(Rails.root.join("db","idsr_metadata","emr_ohsp_facility_map.csv"))
        data = CSV.parse(file,headers: true)
        emr_facility_id = Location.current_health_center.id
        facility = data.select{|row| row["EMR_Facility_ID"].to_i == emr_facility_id}
        ohsp_id = facility[0]["OrgUnit ID"]
      end

      def get_ohsp_de_ids(de,type)
        #this method returns an array ohsp report line ids
        result = []
        #["waoQ016uOz1", "r1AT49VBKqg", "FPN4D0s6K3m", "zE8k2BtValu"]
        #  ds,              de_id     ,  <5yrs       ,  >=5yrs
        puts de
        if type == "weekly"
        file = File.open(Rails.root.join("db","idsr_metadata","idsr_weekly_ohsp_ids.csv"))
        else
        file = File.open(Rails.root.join("db","idsr_metadata","idsr_monthly_ohsp_ids.csv"))
        end
        data = CSV.parse(file,headers: true)
        row = data.select{|row| row["Data Element Name"].strip.downcase.eql?(de.downcase.strip)}
        ohsp_ds_id = row[0]["Data Set ID"]
        result << ohsp_ds_id
        ohsp_de_id = row[0]["UID"]
        result << ohsp_de_id
        option1 = row[0]["<5Yrs"]
        result << option1
        option2 = row[0][">=5Yrs"]
        result << option2

        return result
      end

      def get_data_set_id(type)
        if type == "weekly"
          file = File.open(Rails.root.join("db","idsr_metadata","idsr_weekly_ohsp_ids.csv"))
        else
          file = File.open(Rails.root.join("db","idsr_metadata","idsr_monthly_ohsp_ids.csv"))
        end
        data = CSV.parse(file,headers: true)
        data_set_id = data.first["Data Set ID"]
      end

      def generate_weekly_idsr_report(request=nil,start_date=nil,end_date=nil)

        diag_map = settings["weekly_idsr_map"]

        epi_week = weeks_generator.last.first.strip
        start_date = weeks_generator.last.last.split("to")[0].strip if start_date.nil?
        end_date = weeks_generator.last.last.split("to")[1].strip if end_date.nil?

        #pull the data
        type = EncounterType.find_by_name 'Outpatient diagnosis'
        collection = {}

        diag_map.each do |key,value|
          options = {"<5yrs"=>nil,">=5yrs"=>nil}
          concept_ids = ConceptName.where(name: value).collect{|cn| cn.concept_id}

          data = Encounter.where('encounter_datetime BETWEEN ? AND ?
          AND encounter_type = ? AND value_coded IN (?)
          AND concept_id IN(6543, 6542)',
          start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
          joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
          INNER JOIN person p ON p.person_id = encounter.patient_id').\
          select('encounter.encounter_type, obs.value_coded, p.*')

          #under_five
          under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                      collect{|record| record.person_id}
          options["<5yrs"] = under_five
          #above 5 years
          over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
                      collect{|record| record.person_id}

          options[">=5yrs"] =  over_five

          collection[key] = options
        end
          if request == nil
           response = send_data(collection,"weekly")
          end
          
        return collection
      end

      #idsr monthly report
      def generate_monthly_idsr_report(request=nil,start_date=nil,end_date=nil)
        diag_map = settings["monthly_idsr_map"]
        epi_month = months_generator.first.first.strip
        start_date = months_generator.first.last[1].split("to").first.strip if start_date.nil?
        end_date =  months_generator.first.last[1].split("to").last.strip if end_date.nil?
        type = EncounterType.find_by_name 'Outpatient diagnosis'
        collection = {}

        special_indicators = ["Malaria in Pregnancy",
                              "HIV New Initiated on ART",
                              "Diarrhoea In Under 5",
                              "Malnutrition In Under 5",
                              "Underweight Newborns < 2500g in Under 5 Cases",
                              "Severe Pneumonia in under 5 cases"]

        diag_map.each do |key,value|
          options = {"<5yrs"=>nil,">=5yrs"=>nil}
          concept_ids = ConceptName.where(name: value).collect{|cn| cn.concept_id}
          if !special_indicators.include?(key)
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              #under_five
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                          collect{|record| record.person_id}.uniq
              options["<5yrs"] = under_five
              #above 5 years
              over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
                          collect{|record| record.person_id}.uniq

              options[">=5yrs"] =  over_five

              collection[key] = options
          else
            if key.eql?("Malaria in Pregnancy")
              mal_patient_id = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              mal_patient_id=   mal_patient_id.collect{|record| record.person_id}
              #find those that are pregnant
              preg = Observation.where(["concept_id = 6131 AND obs_datetime
                                         BETWEEN ? AND ? AND person_id IN(?)
                                          AND value_coded =1065",
                                          start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
                                          end_date.to_date.strftime('%Y-%m-%d 23:59:59'),mal_patient_id ])

               options[">=5yrs"] =   preg.collect{|record| record.person_id} rescue 0
               collection[key] = options
            end

            if key.eql?("HIV New Initiated on ART")
             data =  ActiveRecord::Base.connection.select_all(
                        "SELECT * FROM temp_earliest_start_date
                            WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
                            AND date_enrolled = earliest_start_date
                             GROUP BY patient_id" ).to_hash

              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
                             collect{|record| record["patient_id"]}

              over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
                             collect{|record| record["patient_id"]}

              options["<5yrs"] = under_five
              options[">=5yrs"] =  over_five

              collection[key] = options
            end

            if key.eql?("Diarrhoea In Under 5")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              #under_five
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                          collect{|record| record.person_id}
              options["<5yrs"] = under_five
              collection[key] = options
            end


            if key.eql?("Malnutrition In Under 5")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              #under_five
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                          collect{|record| record.person_id}
              options["<5yrs"] = under_five
              collection[key] = options
            end


            if key.eql?("Underweight Newborns < 2500g in Under 5 Cases")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              #under_five
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                          collect{|record| record.person_id}
              options["<5yrs"] = under_five
              collection[key] = options
            end

            if key.eql?("Severe Pneumonia in under 5 cases")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')

              #under_five
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                          collect{|record| record.person_id}
              options["<5yrs"] = under_five
              collection[key] = options
            end
          end
        end
          if request == nil
           response = send_data(collection,"monthly")
          end
        return collection
      end

      def generate_hmis_15_report(start_date=nil,end_date=nil)

        diag_map = settings["hmis_15_map"]
    
        #pull the data
        type = EncounterType.find_by_name 'Outpatient diagnosis'
        collection = {}
    
        special_indicators = ["Malaria - new cases (under 5)",
          "Malaria - new cases (5 & over)",
          "HIV confirmed positive (15-49 years) new cases",
          "Diarrhoea non - bloody -new cases (under5)",
          "Malnutrition - new case (under 5)",
          "Acute respiratory infections - new cases (U5)"
        ]
    
        diag_map.each do |key,value|
          options = {"ids"=>nil}
          concept_ids = ConceptName.where(name: value).collect{|cn| cn.concept_id}
    
          if !special_indicators.include?(key)
            data = Encounter.where('encounter_datetime BETWEEN ? AND ?
            AND encounter_type = ? AND value_coded IN (?)
            AND concept_id IN(6543, 6542)',
            start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
            end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
            joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
            INNER JOIN person p ON p.person_id = encounter.patient_id').\
            select('encounter.encounter_type, obs.value_coded, p.*')
    
            # #under_five
            # under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
            #             collect{|record| record.person_id}
            # options["<5yrs"] = under_five
            # #above 5 years
            # over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
            #             collect{|record| record.person_id}
    
            # options[">=5yrs"] =  over_five
    
            all = data.collect{|record| record.person_id}
    
    
            options["ids"] = all
    
            collection[key] = options
          else
            if key.eql?("Malaria - new cases (under 5)")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')
    
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
                            collect{|record| record["person_id"]}
    
              options["ids"] = under_five
    
              collection[key] = options
            end
    
            if key.eql?("Malaria - new cases (5 & over)")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')
    
              over_and_five = data.select{|record| calculate_age(record["birthdate"])  >= 5 }.\
                            collect{|record| record["person_id"]}
    
              options["ids"] = over_and_five
    
              collection[key] = options
            end
    
            if key.eql?("HIV confirmed positive (15-49 years) new cases")
              data =  ActiveRecord::Base.connection.select_all(
                "SELECT * FROM temp_earliest_start_date
                  WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
                  AND date_enrolled = earliest_start_date
                  GROUP BY patient_id" ).to_hash
    
              over_and_15_49 = data.select{|record| calculate_age(record["birthdate"])  >= 15 && calculate_age(record["birthdate"]) <=49 }.\
                     collect{|record| record["patient_id"]}
    
              options["ids"] = over_and_15_49
    
              collection[key] = options
            end

            if key.eql?("Diarrhoea non - bloody -new cases (under5)")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')
    
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
                            collect{|record| record["person_id"]}
    
              options["ids"] = under_five

              collection[key] = options
            end

            if key.eql?("Malnutrition - new case (under 5)")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')
    
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
                            collect{|record| record["person_id"]}
    
              options["ids"] = under_five

              collection[key] = options
            end

            if key.eql?("Acute respiratory infections - new cases (U5)")
              data = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND value_coded IN (?)
              AND concept_id IN(6543, 6542)',
              start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
              end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
              joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
              INNER JOIN person p ON p.person_id = encounter.patient_id').\
              select('encounter.encounter_type, obs.value_coded, p.*')
    
              under_five = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
                            collect{|record| record["person_id"]}
    
              options["ids"] = under_five

              collection[key] = options
            end

        end
        end
         collection
      end

      def disaggregate(disaggregate_key, concept_ids, start_date, end_date, type)
        options = {"ids"=>nil}
        data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND value_coded IN (?)
        AND concept_id IN(6543, 6542)',
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
        joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
        INNER JOIN person p ON p.person_id = encounter.patient_id').\
        select('encounter.encounter_type, obs.value_coded, p.*')

        if disaggregate_key == "less"
        options["ids"] = data.select{|record| calculate_age(record["birthdate"]) < 5 }.\
        collect{|record| record["person_id"]}
        else 
          if disaggregate_key == "greater"
            options["ids"] = data.select{|record| calculate_age(record["birthdate"]) >= 5 }.\
            collect{|record| record["person_id"]}
          end
        end

        options
      end

      def generate_hmis_17_report(start_date=nil,end_date=nil)
        diag_map = settings["hmis_17_map"]
        collection = {}
        special_indicators = [
          "Referals from other institutions",
          "OPD total attendance",
          "Referal to other institutions",
          "Malaria 5 years and older - new",
          "HIV/AIDS - new"
        ]
        special_under_five_indicators = [
          "Measles under five years - new",
          "Pneumonia under 5 years- new",
          "Dysentery under 5 years - new",
          "Diarrhoea non - bloody -new cases (under5)",
          "Malaria under 5 years - new",
          "Acute respiratory infections U5 - new"
        ]

        
        reg_data = registration_report(start_date,end_date)
       
        data =Observation.where("obs_datetime BETWEEN ? AND ? AND c.voided = ? AND obs.concept_id IN (?) ",
          start_date.to_date.strftime('%Y-%m-%d 00:00:00'), end_date.to_date.strftime('%Y-%m-%d 23:59:59'),0, [6543, 6542]).\
          joins('INNER JOIN concept_name c ON c.concept_id = obs.value_coded
          INNER JOIN person p ON p.person_id = obs.person_id').\
          pluck("c.name, CASE WHEN  (SELECT timestampdiff(year, birthdate, '#{end_date.to_date.strftime('%Y-%m-%d')}')) >= 5 THEN 'more_than_5' 
          ELSE 'less_than_5' END AS age_group,p.person_id").group_by(&:shift)

          diag_map.each do |key, value|
            collection[key] = { "ids" => [] }
            if key.eql?("OPD total attendance")
              collection[key]["ids"] = reg_data.map { |item| item[1] }
            else
              if key.eql?("Referals from other institutions")
                reg_data = reg_data.rows.group_by(&:shift)
                collection[key]["ids"]= reg_data['Referral'].flatten
              end
            end
            data.each do |phrase, counts|
              next unless value.include?(phrase)
            
              counts.each do |label, count|
                if !key.eql?("Malaria 5 years and older - new") && !special_under_five_indicators.include?(key)
                  collection[key]["ids"] << count
                else
                  if ((special_under_five_indicators.include?(key) && label.eql?("less_than_5")) ||
                      (key.eql?("Malaria 5 years and older - new") && label.eql?("more_than_5")))
                    collection[key]["ids"] << count
                  end
                end
              end
            end
          end
          collection
      end

      def registration_report(start_date=nil,end_date=nil)
        ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
        MIN(IFNULL(c.name, 'Unidentified')) AS visit_type,
          obs.person_id
          FROM `encounter`
          LEFT JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.voided = 0
          LEFT JOIN concept_name c ON c.concept_id = obs.value_coded 
          AND c.name IN ('New patient','Revisiting','Referral') AND c.voided = 0
          WHERE
              encounter.voided = 0
              AND  DATE(encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
              AND encounter.program_id = 14 -- OPD program
          GROUP BY encounter.patient_id, DATE(encounter_datetime);
        SQL
      end

      def generate_notifiable_disease_conditions_report(start_date=nil,end_date=nil)
        diag_map = settings["notifiable_disease_conditions"]

        start_date = Date.today.strftime("%Y-%m-%d") if start_date.nil?
        end_date = Date.today.strftime("%Y-%m-%d") if end_date.nil?

        type = EncounterType.find_by_name 'Outpatient diagnosis'
        collection = {}
        concept_name_for_sms_portal = {}

        diag_map.each do |key,value|
          options = {"<5yrs"=>nil,">=5yrs"=>nil}
          concept_ids = ConceptName.where(name: value).collect{|cn| cn.concept_id}

          data = Encounter.where('encounter_datetime BETWEEN ? AND ?
          AND encounter_type = ? AND value_coded IN (?)
          AND concept_id IN(6543, 6542)',
          start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,concept_ids).\
          joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
          INNER JOIN person p ON p.person_id = encounter.patient_id').\
          select('encounter.encounter_type, obs.value_coded, p.*')

          #under_five
          under_five = data.select{|record| calculate_age(record["birthdate"]) < 5}.\
                      collect{|record| record.person_id}
          options["<5yrs"] = under_five
          #above 5 years
          over_five = data.select{|record| calculate_age(record["birthdate"]) >=5 }.\
                      collect{|record| record.person_id}

          options[">=5yrs"] =  over_five

          collection[key] = options

          concept_name_for_sms_portal[key] = concept_ids
        end
        send_data_to_sms_portal(collection, concept_name_for_sms_portal)
        return collection
      end

      # helper menthod
      def months_generator
          months = Hash.new
          count = 1
          curr_date = Date.today
          while count < 13 do
              curr_date = curr_date - 1.month
              months[curr_date.strftime("%Y%m")] = [curr_date.strftime("%B-%Y"),\
                                        (curr_date.beginning_of_month.to_s+" to " + curr_date.end_of_month.to_s)]
              count +=  1
          end
          return months.to_a
      end

      # helper menthod
      def weeks_generator

        weeks = Hash.new
        first_day = (Date.today - (11).month).at_beginning_of_month
        wk_of_first_day = first_day.cweek

        if wk_of_first_day > 1
          wk = first_day.prev_year.year.to_s+"W"+wk_of_first_day.to_s
          dates = "#{(first_day-first_day.wday+1).to_s} to #{((first_day-first_day.wday+1)+6).to_s}"
          weeks[wk] = dates
        end

        #get the firt monday of the year
        while !first_day.monday? do
          first_day = first_day+1
        end
        first_monday = first_day
        #generate week numbers and date ranges

        while first_monday <= Date.today do
            wk = (first_monday.year).to_s+"W"+(first_monday.cweek).to_s
            dates =  "#{first_monday.to_s} to #{(first_monday+6).to_s}"
            #add to the hash
            weeks[wk] = dates
            #step by week
            first_monday += 7
        end
      #remove the last week
      this_wk = (Date.today.year).to_s+"W"+(Date.today.cweek).to_s
      weeks = weeks.delete_if{|key,value| key==this_wk}

      return weeks.to_a
      end

      #Age calculator
      def calculate_age(dob)
        age = ((Date.today-dob.to_date).to_i)/365 rescue 0
      end

      def send_data(data,type)
        # method used to post data to the server
        #prepare payload here
        conn = server_config['ohsp']
        payload = {
          "dataSet" =>get_data_set_id(type),
          "period"=>(type.eql?("weekly") ? weeks_generator.last[0] : months_generator.first[0]),
          "orgUnit"=> get_ohsp_facility_id,
          "dataValues"=> []
        }
         special = ["Severe Pneumonia in under 5 cases","Malaria in Pregnancy",
                   "Underweight Newborns < 2500g in Under 5 Cases","Diarrhoea In Under 5"]

        data.each do |key,value|
          if !special.include?(key)
              option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                          "value"=>value["<5yrs"].size } rescue {}

              option2 = {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[3],
                          "value"=>value[">=5yrs"].size} rescue {}

            #fill data values array
              payload["dataValues"] << option1
              payload["dataValues"] << option2
          else
              case key
                when special[0]
                  option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                              "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                              "value"=>value["<5yrs"].size } rescue {}

                  payload["dataValues"] << option1
                when special[1]
                  option2 = {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                              "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[3],
                              "value"=>value[">=5yrs"].size } rescue {}

                  payload["dataValues"] << option2
                when special[2]
                  option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                              "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                              "value"=>value["<5yrs"].size } rescue {}

                  payload["dataValues"] << option1
                when special[3]
                  option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                              "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                              "value"=>value["<5yrs"].size} rescue {}

                  payload["dataValues"] << option1
              end
          end
        end

        puts "now sending these values: #{payload.to_json}"
        url = "#{conn["url"]}/api/dataValueSets"
        puts url
        puts "pushing #{type} IDSR Reports"
        send = RestClient::Request.execute(method: :post,
                                            url: url,
                                            headers:{'Content-Type'=> 'application/json'},
                                            payload: payload.to_json,
                                            #headers: {accept: :json},
                                            user: conn["username"],
                                            password: conn["password"])

        puts send
      end

      def send_data_to_sms_portal(data, concept_name_collection)
        conn2 = server_config['idsr_sms']
        data = data.select {|k,v| v.select {|kk,vv| vv.length > 0}.length > 0}
        payload = {
          "email"=> conn2["username"],
          "password" => conn2["password"],
          "emr_facility_id" => Location.current_health_center.id,
          "emr_facility_name" => Location.current_health_center.name,
          "payload" => data,
          "concept_name_collection" => concept_name_collection
        }
      
     
      
        begin
          response = RestClient::Request.execute(method: :post,
            url: conn2["url"],
            headers:{'Content-Type'=> 'application/json'},
            payload: payload.to_json
          )
        rescue RestClient::ExceptionWithResponse => res
          if res.class == RestClient::Forbidden
            puts "error: #{res.class}"
          end
        end
      
        if response.class != NilClass
          if response.code == 200
            puts "success: #{response}"
          end
        end
        
        end

    end
  end

end
