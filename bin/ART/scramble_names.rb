# frozen_string_literal: true

def process_names(patient)
  patient.person.names.each do |name|
    name.given_name = Faker::Name.first_name
    name.middle_name = Faker::Name.middle_name
    name.family_name = Faker::Name.last_name
    name.save!
  end
end

def process_addresses(patient)
  patient.person.addresses.each do |address|
    # limit to 50 character
    address.address1 = Faker::Address.full_address.first(50)
    address.address2 = Faker::Address.full_address.first(50)
    address.city_village = Faker::Address.full_address.first(50)
    address.country = Faker::Address.country.first(50)
    address.county_district = Faker::Address.full_address.first(50)
    address.neighborhood_cell = Faker::Address.full_address.first(50)
    address.state_province = Faker::Address.full_address.first(50)
    address.township_division = Faker::Address.full_address.first(50)
    address.save!
  end
end

def process_occupation(patient)
  patient.person.person_attributes.where(person_attribute_type_id: 13).each do |person_attribute|
    person_attribute.value = Faker::Job.title
    person_attribute.save!
  end
end

def generate_phone_number
  country_code = '+265'
  first_two_digits = [88, 89, 98, 99, 1, 212].sample
  seven_random_digits = rand(10**7).to_s.rjust(7, '0')
  phone_number = "#{country_code}#{first_two_digits}#{seven_random_digits}"

  phone_number = "#{country_code}#{first_two_digits}#{seven_random_digits.first(6)}" if [1, 212].include?(first_two_digits)

  phone_number
end

def process_phone_number(patient)
  patient.person.person_attributes.where(person_attribute_type_id: [12, 14, 15]).each do |person_attribute|
    person_attribute.value = generate_phone_number
    person_attribute.save!
  end
end

def process_patient
  pool = Concurrent::FixedThreadPool.new(40)
  Patient.all.each do |patient|
    puts "Processing patient #{patient.id}"
    pool.post do
      process_names patient
      process_addresses patient
      process_phone_number patient
      process_occupation patient
    end
  end
  pool.shutdown
  pool.wait_for_termination
  Rails.logger.info 'Done'
end

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
ActiveRecord::Base.logger.level = :debug

User.current = User.first
Location.current = Location.first

process_patient
