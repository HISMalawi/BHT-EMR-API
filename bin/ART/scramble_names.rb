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

def process_patient
  Patient.all.each do |patient|
    puts "Processing patient #{patient.id}"
    process_names patient
    process_addresses patient
  end
end

User.current = User.first
Location.current = Location.first

ActiveRecord::Base.transaction do
  process_patient
end
