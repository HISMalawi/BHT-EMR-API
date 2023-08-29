require 'roo'
require 'rest-client'

DEV_ENV = 'https://commcaredev.hismalawi.org/a/egpafmw-development-space/importer/excel/bulk_upload_api/'
PROD_ENV = 'https://comcarehq.hismalawi.org/a/egpaf-malawi-project/importer/excel/bulk_upload_api/'

PROD_FILE = 'commcare_project_data_production'
DEV_FILE = 'commcare_project_data_development'

def choose_environment
  puts "Choose setup environment: \n1. Development \n2. Production"
  env = gets.chomp

  unless ['1', '2'].include? env
    puts 'Invalid option. Please choose 1 or 2'
    return choose_environment
  end
  env
end

def load_excel_file(file_path)
  excel = Roo::Spreadsheet.open(file_path)
  
  worksheets = excel.sheets.map do |sheet_name|
    sheet = excel.sheet(sheet_name)
    headers = sheet.row(1)
    data = []
    
    (2..sheet.last_row).each do |row|
      row_data = {}

      sheet.row(row).each_with_index do |value, col|
        row_data[headers[col]] = value
      end
      
      data << row_data
    end

    { sheet_name => data }
  end
  
  worksheets
end

env = choose_environment
workbooks = load_excel_file("#{Rails.root}/db/hts_metadata/#{env == '1' ? DEV_FILE : PROD_FILE}.xlsx")
@types, @countries, @regions, @districts, @health_facilities = workbooks

def is_valid_credentials?(username, password, env)
  begin
    rest_client = RestClient::Resource.new(env == '1' ? DEV_ENV : PROD_ENV, user: username, password: password, verify_ssl: false)
    rest_client.post({})
  rescue RestClient::ExceptionWithResponse => e
    return false if e.response.code == 401
  end
  true
end

def setup_config(env)
  puts 'Enter your site code:'
  site_code = gets.chomp
  
  facility = @health_facilities['health-facility'].find { |f| f['data: site_id'] == site_code }

  unless facility
    puts 'Site code not found'
    return setup_config(env)
  end

  facility_name = facility['name']
  facility_id = facility['location_id']

  dhis2_code = facility['data: dhis2_code']

  parent_facility = facility['parent_site_code']

  district = @districts['district'].find { |d| d['site_code'] == parent_facility }
  district_name = district['name']
  district_id = district['location_id']

  parent_district = district['parent_site_code']
  region = @regions['region'].find { |r| r['site_code'] == parent_district }
  region_name = region['name']
  region_id = region['location_id']

  puts "Facility name: #{facility_name} District: #{district_name} \nRegion: #{region_name} \nDHIS2 code: #{dhis2_code}"
  puts 'Is this correct? (Y/N)'
  prompt = gets.chomp
  
  return setup_config(env) if prompt.downcase == 'n'

  unless prompt.downcase == 'y'
    puts 'Invalid input'
    return setup_config(env)
  end

  puts 'Enter your commcare username:'
  username = gets.chomp

  puts 'Enter your commcare password:'
  password = gets.chomp

  if username.empty? || password.empty?
    puts 'Username or password cannot be blank'
    return setup_config(env)
  end

  unless is_valid_credentials?(username, password, env)
    puts 'Invalid username or password, cannot authenticate'
    return setup_config(env)
  end
  
  puts 'Setting up config...'
  config = {
    endpoint: env == '1' ? DEV_ENV : PROD_ENV,
    health_facility_id: facility_id,
    health_facility_name: facility_name,
    district_id: district_id.to_i,
    district_name: district_name,
    region_id: region_id.to_i,
    region_name: region_name,
    site_id: site_code.to_i,
    dhis2_code: dhis2_code.to_i,
    username: username,
    password: password
  }
  file = YAML.load_file("#{Rails.root}/config/ait.yml")

  file.each_key do |key|
    file[key] = config[key.to_sym] if config[key.to_sym]
  end

  File.open("#{Rails.root}/config/ait.yml", 'w') { |f| f.write file.to_yaml }
  puts 'Config saved to config/ait.yml'
end

setup_config(env)
