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
    address.save!
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
  patient.person.person_attributes.where(person_attribute_type_id: 12).each do |person_attribute|
    person_attribute.value = generate_phone_number
    person_attribute.save!
  end
end

def process_patient
  Parallel.each(Patient.all, in_threads: 10) do |patient|
    puts "Processing patient #{patient.id}"
    process_names patient
    process_addresses patient
    process_phone_number patient
  end
end

User.current = User.first
Location.current = Location.first

ActiveRecord::Base.transaction do
  process_patient
end
