require 'roo'

@dev_env = 'https://commcaredev.hismalawi.org/a/egpafmw-development-space/importer/excel/bulk_upload_api/'
@prod_env = 'https://comcarehq.hismalawi.org/a/egpaf-malawi-project/importer/excel/bulk_upload_api/'

@prod_file = 'commcare_project_data_production'
@dev_file = 'commcare_project_data_development'

puts "Choose setup environment: \n1. Development \n2. Production"
@env = gets.chomp

workbooks = load_excel_file("#{Rails.root}/db/hts_metadata/#{@env == '1' ? @dev_file : @prod_file}.xlsx")
@types, @countries, @regions, @districts, @health_facilities = workbooks


# Function to load an Excel file and convert each sheet into a hash
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


def setup_config


  puts 'Enter your site code:'
  site_code = gets.chomp
  
  facility = @health_facilities['health-facility'].find { |f| f['data: site_id'] == site_code }

  return puts 'Site code not found' unless facility

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
  
  return setup_config if prompt.downcase == 'n'

  return puts 'Invalid input' unless prompt.downcase == 'y'

  puts 'Enter your commcare username:'
  username = gets.chomp

  puts 'Enter your commcare password:'
  password = gets.chomp
  
  puts 'Setting up config...'
  config = {
    endpoint: env == '1' ? @dev_env : @prod_env,
    health_facility_id: facility_id.to_i,
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

setup_config