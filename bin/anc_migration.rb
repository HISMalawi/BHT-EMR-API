# frozen_string_literal: true

require 'yaml'

# Geth the anc database name
database = YAML.load(File.open("#{Rails.root}/config/database.yml", 'r'))['anc_database']['database']

# method to create a beautiful csv file
def fetch_diff(database)
  anc = ActiveRecord::Base.connection.select_all <<~SQL
    select identifier, person_name.given_name, person_name.family_name
    from #{database}.person_name
    inner join #{database}.patient_identifier
    on person_name.person_id = patient_identifier.patient_id
    where patient_identifier.identifier_type = 3
    and patient_identifier.voided = 0
    and person_name.voided = 0
  SQL

  openmrs = ActiveRecord::Base.connection.select_all <<~SQL
    select identifier, person_name.given_name, person_name.family_name
    from person_name
    inner join patient_identifier
    on person_name.person_id = patient_identifier.patient_id
    where patient_identifier.voided = 0
    and person_name.voided = 0
  SQL

  anc.to_a - openmrs.to_a
end

def fetch_person_names(database, id)
  conn = database.blank? ? '' : "#{database}."
  ActiveRecord::Base.connection.select_one <<~SQL
    select person_name.given_name, person_name.family_name
    from #{conn}person_name
    where voided = 0
    and person_id = (select patient_id from #{conn}patient_identifier where identifier = '#{id}' and voided = 0 limit 1)
  SQL
end

def fetch_person(database, id)
  conn = database.blank? ? '' : "#{database}."
  ActiveRecord::Base.connection.select_one <<~SQL
    select *
    from #{conn}person
    where voided = 0
    and person_id = (select patient_id from #{conn}patient_identifier where identifier = '#{id}' and voided = 0 limit 1)
  SQL
end

def fetch_person_address(database, id)
  conn = database.blank? ? '' : "#{database}."
  ActiveRecord::Base.connection.select_one <<~SQL
    select address2 as home_region, county_district as ta,
    (select name from #{conn}village where village_id = person_address.neighborhood_cell) as home_village,
    city_village as current_village
    from #{conn}person_address
    where voided = 0
    and person_id = (select patient_id from #{conn}patient_identifier where identifier = '#{id}' and voided = 0 limit 1)
  SQL
end

def fetch_person_attribute(database, id)
  conn = database.blank? ? '' : "#{database}."
  ActiveRecord::Base.connection.select_all <<~SQL
    select *
    from #{conn}person_attribute
    where voided = 0
    and person_attribute_type_id in (12,14,15)
    and person_id = (select patient_id from #{conn}patient_identifier where identifier = '#{id}' and voided = 0 limit 1)
  SQL
end

def fetch_other_identifiers(database, id)
  conn = database.blank? ? '' : "#{database}."
  ActiveRecord::Base.connection.select_all <<~SQL
    select *
    from #{conn}patient_identifier
    where voided = 0
    and identifier != '#{id}'
    and patient_id = (select patient_id from #{conn}patient_identifier where identifier = '#{id}' and voided = 0 limit 1)
  SQL
end

def create_csv(database)
  result = fetch_diff(database)
  return if result.blank?

  file = File.new('names_mismatch.csv', 'a+')
  file.puts('identifier, anc first name, anc last name, anc DOB, anc gender, anc home region, anc TA, anc home village, anc current village, anc all identifiers, anc person id, anc phone number,openmrs first name, openmrs last name, openmrs DOB, openmrs gender, openmrs home region, openmrs TA, openmrs home village, openmrs current village, openmrs all identifiers, openmrs person id, openmrs phone number')
  result.each do |patient|
    anc_person = fetch_person(database, patient['identifier'])
    anc_address = fetch_person_address(database, patient['identifier'])
    anc_attribute = fetch_person_attribute(database, patient['identifier']).map { |p| p['value'] }.join('/')
    anc_identifier = fetch_other_identifiers(database, patient['identifier']).map { |p| p['identifier'] }.join('/')

    open_person = fetch_person(nil, patient['identifier']) || { birthdate: nil, person_id: nil, gender: nil }
    open_name = fetch_person_names(nil, patient['identifier']) || { given_name: nil, family_name: nil }
    open_address = fetch_person_address(nil, patient['identifier']) || {home_village: nil, home_region: nil, ta: nil, current_village: nil}
    open_attribute = fetch_person_attribute(nil, patient['identifier']).map { |p| p['value'] }.join('/')
    open_identifier = fetch_other_identifiers(nil, patient['identifier']).map { |p| p['identifier'] }.join('/')

    file.puts <<~SQL
#{patient['identifier']},#{patient['given_name']},#{patient['family_name']},#{anc_person['birthdate']},#{anc_person['gender']},#{anc_address['home_region']},#{anc_address['ta']},#{anc_address['home_village']},#{anc_address['current_village']},#{anc_identifier},#{anc_person['person_id']},#{anc_attribute},#{open_name['given_name']},#{open_name['family_name']},#{open_person['birthdate']},#{open_person['gender']},#{open_address['home_region']},#{open_address['ta']},#{open_address['home_village']},#{open_address['current_village']},#{open_identifier},#{open_person['person_id']},#{open_attribute}
    SQL
  end
  file.close
end

# fetch user inputs on how this script should run
what_to_run = ARGV[0].to_i

if what_to_run.zero?
  ANCService::ANCMigration.new(database, ARGV[1].to_f).main
elsif what_to_run == 1
  ANCService::ANCReverseMigration.new({ database: database, migration_date: ARGV[1] }).main
elsif what_to_run == 2
  ANCService::ANCMappingMigration.new(database, ARGV[1].to_f).map_linkage_between_anc_and_openmrs
else
  puts create_csv(database)
end
