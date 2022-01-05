class << self

  def get_ohsp_facility_id
    file = File.open(Rails.root.join("db","idsr_metadata","emr_ohsp_facility_map.csv"))
    data = CSV.parse(file,headers: true)
    emr_facility_id = Location.current_health_center.id
    facility = data.select{|row| row["EMR_Facility_ID"].to_i == emr_facility_id}
    ohsp_id = facility[0]["OrgUnit ID"]
  end

  def send_data(data,type)
    # method used to post data to the server
    #prepare payload here
    conn = settings["headers"]
    payload = {
      "orgUnit"=> get_ohsp_facility_id,
      "dataValues"=> []
    }
     special = ["Severe Pneumonia in under 5 cases","Malaria in Pregnancy",
               "Underweight Newborns < 2500g in Under 5 Cases","Diarrhoea In Under 5"]

    data.each do |key,value|
      if !special.include?(key)
          option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                      "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                      "value"=>value["<5yrs"].size }

          option2 = {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                      "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[3],
                      "value"=>value[">=5yrs"].size}

        #fill data values array
          payload["dataValues"] << option1
          payload["dataValues"] << option2
      else
          case key
            when special[0]
              option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                          "value"=>value["<5yrs"].size }

              payload["dataValues"] << option1
            when special[1]
              option2 = {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[3],
                          "value"=>value[">=5yrs"].size }

              payload["dataValues"] << option2
            when special[2]
              option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                          "value"=>value["<5yrs"].size }

              payload["dataValues"] << option1
            when special[3]
              option1 =  {"dataElement"=>get_ohsp_de_ids(key,type)[1],
                          "categoryOptionCombo"=> get_ohsp_de_ids(key,type)[2],
                          "value"=>value["<5yrs"].size}

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
                                        user: conn["user"],
                                        password: conn["pass"])

    puts send
  end
end