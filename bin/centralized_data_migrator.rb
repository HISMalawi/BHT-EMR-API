# For each person migrate all thier data
database_config = Psych.load(File.read('config/database.yml'), aliases: true).freeze
source_db = database_config['centralized_source_db']['database']
database_config[Rails.env]['database']
SITE_ID = ActiveRecord::Base.connection.execute("SELECT property_value
  FROM #{source_db}.global_property
  WHERE property = 'current_health_center_id'").first[0].to_i
SITE_USER_MAPPING = Rails.root.join('log', "users_mapping_#{SITE_ID}.json")
File.write(SITE_USER_MAPPING, '{}') unless File.exist?(SITE_USER_MAPPING)

def query(model, batch_size, offset, source_db)
  ActiveRecord::Base.connection.select_all("SELECT *
  FROM #{source_db}.#{model} LIMIT #{batch_size} OFFSET #{offset}")
end

def query_in_batches(source_db, batch_size = 1000)
  puts 'Initilizing users...'

  populate_users(source_db)
  populate_global_property(source_db)
  # populate_user_roles(source_db) TODO: Have to think this through
  offset = 0

  loop do
    count = ActiveRecord::Base.connection.select_all("SELECT count(*) count FROM #{source_db}.person")
    count = count.first['count']
    results = ActiveRecord::Base.connection.select_all("SELECT *
      FROM #{source_db}.person LIMIT #{batch_size} OFFSET #{offset}")

    break if results.blank?

    results.each_with_index do |person, i|
      # Process each person record here
      i += 1
      percentage = ((i.to_f / count) * 100).round(2)
      print "processing person record: #{i}/#{count} : #{percentage}%\r"
      populate_person(person.symbolize_keys!)
    
      i + 1
    end

    offset += batch_size
  end
  process_everthing_else(source_db)
end

def process_everthing_else(source_db, batch_size = 1_000)
  offset = 0

  loop do
    count = ActiveRecord::Base.connection.select_all("SELECT count(*) count FROM #{source_db}.person")
    count = count.first['count']
    
    results = ActiveRecord::Base.connection.select_all("SELECT *
      FROM #{source_db}.person LIMIT #{batch_size} OFFSET #{offset}")

    break if results.blank?
    
    results.each_with_index do |person, i|
      i += 1
      percentage = ((i.to_f / count) * 100).round(2)
      print "processing everything else: #{i}/#{count} : #{percentage}%\r"
      person_before_insert = person.dup
      new_person_id = populate_person(person.symbolize_keys!)
      # Populate name
      populate_person_names(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate person addresses
      populate_person_addresses(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate Relationships
      populate_relationship(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate person attributes
      populate_person_attributes(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate patients
      populate_patients(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate patient identifiers
      populate_patient_identifiers(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate patient program
      populate_patient_program(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)

      # Populate patient state
      populate_patient_encounters(person_before_insert.symbolize_keys![:person_id], source_db, new_person_id)
      i + 1
    end
    offset += batch_size
  end
end

def populate_person(person)
  # Add site_id to record
  person.merge!({site_id: SITE_ID})
  # Check if record already exits
  person_exist = Person.unscoped.where(uuid: person[:uuid])
  return person_exist.first.person_id unless person_exist.blank?

  # Get max id and create
  person[:person_id] = nil
  person[:creator] = 1 # Need to update to the proper one
  person[:changed_by] = nil # Will need to change
  person[:voided_by] = nil # will need to update
  new_person = Person.new(person)
  new_person.save
  new_person[:person_id]
end

def populate_person_names(person_id, source_db, new_person_id)
  person_names = ActiveRecord::Base.connection.select_all("SELECT * FROM #{source_db}.person_name where person_id = #{person_id}")
  eligible_names = person_names.select { |name| PersonName.unscoped.where(uuid: name['uuid']).blank? == true }
  return if eligible_names.blank?

  eligible_names.each do |name|
    name.symbolize_keys!
    name.merge!({site_id: SITE_ID})
    name[:person_name_id] = nil
    name[:person_id] = new_person_id
    name[:creator] = 1
    name[:changed_by] = nil # Will need to change
    name[:voided_by] = nil # will need to update
    new_name = PersonName.new(name)
    new_name.save(validate: false)
  end
end

def populate_person_addresses(person_id, source_db, new_person_id)
  person_names_addresses = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.person_address where person_id = #{person_id}")
  eligible_addresses = person_names_addresses.select { |address| PersonAddress.unscoped.where(uuid: address['uuid']).blank? == true }
  return if eligible_addresses.blank?

  eligible_addresses.each do |address|
    address.symbolize_keys!
    address.merge!({site_id: SITE_ID})
    address[:person_address_id] = nil
    address[:person_id] = new_person_id
    address[:creator] = 1
    address[:voided_by] = nil # will need to update
    new_address = PersonAddress.new(address)
    new_address.save(validate: false)
  end
end

def populate_person_attributes(person_id, source_db, new_person_id)
  person_names_attributes = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.person_attribute where person_id = #{person_id}")
  eligible_attributes = person_names_attributes.select do |attribute|
    PersonAttribute.unscoped.where(uuid: attribute['uuid']).blank? == true
  end
  return if eligible_attributes.blank?

  eligible_attributes.each do |attribute|
    attribute.symbolize_keys!
    attribute.merge!({ site_id: SITE_ID })
    attribute[:person_attribute_id] = nil
    attribute[:person_id] = new_person_id
    attribute[:creator] = 1
    attribute[:changed_by] = 1
    attribute[:voided_by] = nil # will need to update
    new_attribute = PersonAttribute.new(attribute)
    new_attribute.save(validate: false)
  end
end

def populate_patients(person_id, source_db, new_person_id)
  patient = ActiveRecord::Base.connection.select_all("SELECT * FROM #{source_db}.patient where patient_id = #{person_id}")
  return unless Patient.unscoped.where(patient_id: new_person_id).blank?

  patient.each do |data|
    data.symbolize_keys!
    data.merge!({site_id: SITE_ID})
    data[:patient_id] = new_person_id
    data[:creator] = 1
    data[:changed_by] = nil # Will need to change
    data[:voided_by] = nil # will need to update
    new_data = Patient.new(data)
    new_data.save(validate: false)
  end
end

def populate_patient_identifiers(person_id, source_db, new_person_id)
  patient_identifiers = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.patient_identifier where patient_id = #{person_id}")
  eligible_patient_identifiers = patient_identifiers.select do |data|
    PatientIdentifier.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_patient_identifiers.blank?

  eligible_patient_identifiers.each do |data|
    data.symbolize_keys!
    data.merge!({ site_id: SITE_ID })
    data[:patient_identifier_id] = nil
    data[:patient_id] = new_person_id
    data[:creator] = 1
    data[:voided_by] = nil # will need to update
    new_data = PatientIdentifier.new(data)
    new_data.save(validate: false)
  end
end

def populate_patient_program(person_id, source_db, new_person_id)
  patient_programs = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.patient_program where patient_id = #{person_id}")
  eligible_patient_programs = patient_programs.select do |data|
    PatientProgram.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_patient_programs.blank?

  eligible_patient_programs.each do |data|
    data.symbolize_keys!
    data.merge!({ site_id: SITE_ID })
    data[:patient_program_id] = nil
    data[:patient_id] = new_person_id
    data[:creator] = 1
    data[:changed_by] = 1
    data[:voided_by] = nil # will need to update
    new_data = PatientProgram.new(data)
    new_data.save(validate: false)
  end
end

def populate_patient_encounters(person_id, source_db, new_person_id)
  patient_encounters = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.encounter where patient_id = #{person_id}")
  eligible_patient_encounters = patient_encounters.select do |data|
    Encounter.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_patient_encounters.blank?

  eligible_patient_encounters.each do |data|
    old_encounter = data.dup
    data.symbolize_keys!
    data.merge!({ site_id: SITE_ID })
    data[:encounter_id] = nil
    data[:patient_id] = new_person_id
    data[:provider_id] = get_person_id(data[:provider_id], source_db) if data[:provider_id]
    data[:creator] = 1
    data[:changed_by] = 1
    data[:voided_by] = nil # will need to update
    new_data = Encounter.new(data)
    ActiveRecord::Base.transaction do
      new_data.save(validate: false)
      populate_corresponding_obs(old_encounter.symbolize_keys!, person_id, source_db, new_data)
    end
  end
end

def populate_corresponding_obs(old_encounter, person_id, source_db, new_encounter)
  patient_obs = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.obs where encounter_id = #{old_encounter[:encounter_id]}")
  eligible_patient_obs = patient_obs.select do |data|
    Observation.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_patient_obs.blank?

  eligible_patient_obs.each do |data|
    data.symbolize_keys!
    old_obs = data.dup
    data.merge!({ site_id: SITE_ID })
    data[:obs_id] = nil
    data[:encounter_id] = new_encounter[:encounter_id]
    data[:person_id] = new_encounter[:patient_id]
    data[:creator] = 1
    data[:voided_by] = nil # will need to update
    data[:order_id] = populate_corresponding_order(old_obs.symbolize_keys!, source_db, new_encounter) if data[:order_id]
    ActiveRecord::Base.transaction do
      new_data = Observation.new(data)
      new_data.save(validate: false)
    end
  end
end

def populate_corresponding_order(old_obs, source_db, new_obs)
  patient_orders = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.orders where order_id = #{old_obs[:order_id]}")
  eligible_patient_orders = patient_orders.select do |data|
    Order.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_patient_orders.blank?
  order_id = ''
  eligible_patient_orders.each do |data|
    data.symbolize_keys!
    data.merge!({ site_id: SITE_ID })
    data[:order_id] = nil
    data[:encounter_id] = new_obs[:encounter_id]
    data[:patient_id] = new_obs[:patient_id]
    data[:creator] = 1
    data[:voided_by] = nil # will need to update
    data[:orderer] = get_new_user_id(data[:orderer], source_db)
    new_data = Order.new(data)
    new_data.save(validate: false)
    order_id = new_data[:order_id]
  end
  order_id
end

def populate_global_property(source_db)
  puts 'Populating global properties'
  global_property = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.global_property")
  eligible_properties = global_property.select do |property|
    GlobalProperty.unscoped.where(uuid: property['uuid']).blank? == true
  end
  return if eligible_properties.blank?

  eligible_properties.each do |property|
    property.symbolize_keys!
    property.merge!({ site_id: SITE_ID })
    GlobalProperty.create!(property)
  end
end

def populate_relationship(person_id, source_db, new_person_id)
  patient_relations = ActiveRecord::Base.connection.select_all("SELECT *
    FROM #{source_db}.relationship where person_a = #{person_id}")
  eligible_relations = patient_relations.select do |data|
    Relationship.unscoped.where(uuid: data['uuid']).blank? == true
  end
  return if eligible_relations.blank?

  eligible_relations.each do |data|
    data.symbolize_keys!
    data.merge!({ site_id: SITE_ID })
    data[:relationship_id] = nil
    data[:person_a] = new_person_id
    data[:person_b] = get_person_id(data[:person_b], source_db)
    data[:creator] = 1
    data[:voided_by] = nil # will need to update
    new_data = Relationship.new(data)
    new_data.save(validate: false)
  end
end

def get_person_id(old_person_id, source_db)
  person_uuid = ActiveRecord::Base.connection.select_all("SELECT uuid FROM #{source_db}.person
                                                          WHERE person_id = #{old_person_id}")
  Person.unscoped.find_by_uuid(person_uuid.first['uuid']).person_id
end

def create_user_person(user, source_db)
  person = ActiveRecord::Base.connection.select_one(" SELECT * FROM
  #{source_db}.person where person_id = #{user[:person_id]}").symbolize_keys!
  populate_person(person)
end

def populate_users(source_db)
  puts 'Populating Users .....'
  site_users = JSON.load(File.read(SITE_USER_MAPPING))
  query('users', 1_000, 0, source_db).each do |user|
    user.symbolize_keys!
    old_user_id = user[:user_id]

    next if User.unscoped.where(uuid: user[:uuid]).present?

    user.merge!( {site_id: SITE_ID} )
    user[:user_id] = nil
    user[:creator] = 1
    user[:changed_by] = 1
    user[:person_id] = create_user_person(user, source_db)
    new_user = User.new(user)
    if new_user.save(validate: false)
      site_users[old_user_id.to_i] = new_user[:user_id]
      data = JSON.dump(site_users)
      File.open(SITE_USER_MAPPING, 'w') { |file| file.puts data }
      Rails.logger.info
    else
      Rails.logger.error
    end
  end
end

def get_new_user_id(old_user_id, source_db)
  user_uuid = ActiveRecord::Base.connection.select_one("SELECT uuid FROM #{source_db}.users where user_id = #{old_user_id}")
  User.unscoped.find_by_uuid(user_uuid['uuid']).user_id
end

def populate_user_roles(source_db)
  puts 'Populating user roles ....'
  query('user_role', 1_000, 0, source_db).each do |role|
    role.symbolize_keys!
    role.merge!({ site_id: SITE_ID })
    role[:user_id] = get_new_user_id(role[:user_id], source_db)

    next if UserRole.unscoped.where(role).present?

    puts role
    new_role = UserRole.new(role)
    new_role.save(validate: false)
  end
end

query_in_batches(source_db)