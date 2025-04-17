# Create missing tables

sql_files = %i[bypass_migrations moh_regimens_v2021 spine_adaptaion spine_concepts_adaptation]

sql_files.each do |file|
  sql = File.read("db/sql/#{file}.sql")
  statements = sql.split(/;[\r\n]+/)
  statements.each do |statement|
    next if statement.strip.empty?

    ActiveRecord::Base.connection.execute(statement)
  end
end

# Set site to queens
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = '614' WHERE `property` = 'current_health_center_id';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'Queen Elizabeth Central Hospital' WHERE `property` = 'current_health_center_name';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'QECH' WHERE `property` = 'site_prefix';")
# Update program ID
ActiveRecord::Base.connection.execute('UPDATE encounter SET program_id = 31;')
User.where(user_id: 1).update(person_id: 1)

