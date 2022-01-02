require 'csv'

class OPDService::Reports::HMIS15

  def find_report(start_date:, end_date:, **_extra_kwargs)
    #hmis15(start_date, end_date)
    generate_hmis_15_report(request=nil,start_date,end_date)
  end

  # def hmis15(start_date, end_date)
  # end

  # def get_ohsp_facility_id
  #   file = File.open(Rails.root.join("db","idsr_metadata","emr_ohsp_facility_map.csv"))
  #   data = CSV.parse(file,headers: true)
  #   emr_facility_id = Location.current_health_center.id
  #   facility = data.select{|row| row["EMR_Facility_ID"].to_i == emr_facility_id}
  #   ohsp_id = facility[0]["OrgUnit ID"]
  # end


  # def get_ohsp_de_ids(de,type)
  #   #this method returns an array ohsp report line ids
  #   result = []
  #   #["waoQ016uOz1", "r1AT49VBKqg", "FPN4D0s6K3m", "zE8k2BtValu"]
  #   #  ds,              de_id     ,  <5yrs       ,  >=5yrs
  #   # puts de
  #   file = File.open(Rails.root.join("db","idsr_metadata","idsr_weekly_ohsp_ids.csv"))
  #   data = CSV.parse(file,headers: true)
  #   row = data.select{|row| row["Data Element Name"].strip.downcase.eql?(de.downcase.strip)}
  #   ohsp_ds_id = row[0]["Data Set ID"]
  #   result << ohsp_ds_id
  #   ohsp_de_id = row[0]["UID"]
  #   result << ohsp_de_id
  #   option1 = row[0]["<5Yrs"]
  #   result << option1
  #   option2 = row[0][">=5Yrs"]
  #   result << option2

  #   return result
  # end

  def generate_hmis_15_report(request=nil,start_date=nil,end_date=nil)

    diag_map = settings["hmis_15_map"]

    #pull the data
    type = EncounterType.find_by_name 'Outpatient diagnosis'
    collection = {}

    special_indicators = ["Malaria - new cases (under 5)",
      "Malaria - new cases (5 & over)",
      "HIV confirmed positive (15-49 years) new cases"
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
    end
    end
     collection
  end

  def calculate_age(dob)
    age = ((Date.today-dob.to_date).to_i)/365 rescue 0
  end

  def settings
    file = File.read(Rails.root.join("db","idsr_metadata","idsr_ohsp_settings.json"))
    config = JSON.parse(file)
  end

  # def send_data(data,type)
  #   # method used to post data to the server
  #   #prepare payload here
  #   conn = settings["headers"]
  #   payload = {
  #     "dataValues"=> []
  #   }
  #    special = ["Severe Pneumonia in under 5 cases","Malaria in Pregnancy",
  #              "Underweight Newborns < 2500g in Under 5 Cases","Diarrhoea In Under 5"]

  #   data.each do |key,value|
  #     if !special.include?(key)
  #         option1 =  {
  #                     "value"=>value["<5yrs"].size }

  #         option2 = {
  #                     "value"=>value[">=5yrs"].size}

  #       #fill data values array
  #         payload["dataValues"] << option1
  #         payload["dataValues"] << option2
  #     else
  #         case key
  #           when special[0]
  #             option1 =  {
  #                         "value"=>value["<5yrs"].size }

  #             payload["dataValues"] << option1
  #           when special[1]
  #             option2 = {
  #                         "value"=>value[">=5yrs"].size }

  #             payload["dataValues"] << option2
  #           when special[2]
  #             option1 =  {
  #                         "value"=>value["<5yrs"].size }

  #             payload["dataValues"] << option1
  #           when special[3]
  #             option1 =  {
  #                         "value"=>value["<5yrs"].size}

  #             payload["dataValues"] << option1
  #         end
  #     end
  #   end

  #   puts payload
  #   payload
  # end


end