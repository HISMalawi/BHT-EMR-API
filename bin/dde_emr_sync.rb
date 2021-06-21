#Load configs
@configs = YAML.load_file("#{Rails.root}/config/application.yml")['dde']
@url = @configs['url']
@username = @configs['hiv program']['username']
@password = @configs['hiv program']['password']

require 'rest-client'

#Check for update tracker or create on
def tracker
  tracker = GlobalProperty.find_by_property('dde_update_tracker_seq')
  if tracker.blank?
    tracker = GlobalProperty.create!(property: 'dde_update_tracker_seq',
                           property_value: 0,
                           description: 'DDE EMR updates tracker')
  else
    tracker[:property_value].to_i
  end
    tracker[:property_value].to_i
end

def authenticate
    url = "#{@url}/v1/login?username=#{@username}&password=#{@password}"

    token = JSON.parse(RestClient.post(url,headers={}))['access_token']
end

def token_valid(token)
  url = "http://#{@url}/v1/verify_token"

  response = JSON.parse(RestClient.post(url,{'token' => token}.to_json, {content_type: :json, accept: :json}))['message']

  if response == 'Successful'
    return true
  else
    return false
  end
end

def update_record(record)
  person_obj = get_person_obj(record.symbolize_keys)
  person_id = PatientIdentifier.find_by_identifier(person_obj[:identifiers][:doc_id])
  return if person_id.blank?
  person_id = person_id[:patient_id]

  #update person
  person = Person.find_by_person_id(person_id)
  person.update(person_obj[:person].to_hash)

  #update person names
  person_names = PersonName.find_by_person_id(person_id)
  person_names.update(person_obj[:person_names].to_hash)

  #Upate person addresses
  person_address = PersonAddress.find_by('person_id = ? AND voided = ?', person_id, 0)
  ActiveRecord::Base.connection.transaction do
    person_address.update(voided: 1,
                          void_reason: 'dde update',
                          date_voided: Time.now,
                          voided_by: 1 )
    PersonAddress.create!(
            person_id: person_id,
            state_province: person_obj[:current_district],
            city_village: person_obj[:current_village],
            township_division: person_obj[:current_traditional_authority],
            address2: person_obj[:home_district],
            neighborhood_cell: person_obj[:home_village],
            county_district: person_obj[:home_traditional_authority],
            creator: 1
        )
  end

  #update person attributes
  #PersonService.new.update_person_attributes(person_id,person_obj[:attributes])
end

def pull_dde_updates
  pull_seq = tracker
  location_id = GlobalProperty.find_by_property('current_health_center_id')['property_value'].to_i

  url = "#{@url}/v1/person_changes?site_id=#{location_id}&pull_seq=#{pull_seq}"

  updates = JSON.parse(RestClient.get(url,headers={Authorization: authenticate }))
end

def self.get_person_obj(person, person_attributes = [])
    #This is an active record object
    return {
        person_names: {
              given_name:   person[:first_name],
              family_name:  person[:last_name],
              middle_name:  person[:middle_name]
            },
        person: {
              gender: person[:gender],
              birthdate:  person[:birthdate],
              birthdate_estimated: person[:birthdate_estimated]
            },
        attributes: {
          #occupation: self.get_attribute(person, "Occupation"),
          #cellphone_number: self.get_attribute(person, "Cell phone number"),
        },
        current_district: person[:home_district],
        current_traditional_authority: person[:home_ta],
        current_village: person[:home_village],
        home_district: person[:ancestry_district],
        home_traditional_authority: person[:ancestry_ta],
        home_village: person[:ancestry_village],
        identifiers: {
          npid: person[:npid],
          doc_id: person[:person_uuid]
        },
      }
  end

def main
  if File.exists?("/tmp/dde_emr_sync.lock")
    puts 'Another process running!'
    exit
  else
    FileUtils.touch "/tmp/dde_emr_sync.lock"
  end
  changes = pull_dde_updates
  changes.each do |record|
    ActiveRecord::Base.transaction do
      update_record(record)
      GlobalProperty.find_by_property('dde_update_tracker_seq').update(property_value: record['id'])
    end
  end
  if File.exists?("/tmp/dde_emr_sync.lock")
    FileUtils.rm "/tmp/dde_emr_sync.lock"
  end
end

main
