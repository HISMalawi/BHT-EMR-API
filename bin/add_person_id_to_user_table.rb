# frozen_string_literal: true

def update_admin_password_and_salt
  user = User.find_by_username('admin')
  salt = SecureRandom.base64
  pass = Digest::SHA1.hexdigest("test#{salt}")
  user.update!(password: pass, salt: salt)
end

def add_global_property
  GlobalProperty.create!(property: 'current_health_center_id', property_value: 614) if GlobalProperty.where(property: 'current_health_center_id').blank?
  GlobalProperty.create!(property: 'current_health_center_name', property_value: 'Queen Elizabeth Central Hospital') if GlobalProperty.where(property: 'current_health_center_name').blank?
  GlobalProperty.create!(property: 'site_prefix', property_value: 'QECH') if GlobalProperty.where(property: 'site_prefix').blank?
end

def person_not_in_patient
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT person_id, date_created FROM person where person_id NOT IN (select patient_id from patient);
  SQL
end

def create_person
  Person.create!(creator: User.first.id)
end

def process_users
  person_data = person_not_in_patient
  User.all.each do |user|
    next if user.person_id.present?

    person = person_data.find { |p| p['date_created'] == user.date_created }
    user.person_id = person ? person['person_id'] : create_person.id
    user.save
  end
end

# wrap in a transaction
ActiveRecord::Base.transaction do
  add_global_property
  process_users
  update_admin_password_and_salt
end
