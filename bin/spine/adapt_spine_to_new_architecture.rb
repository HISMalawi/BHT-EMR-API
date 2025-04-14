# Create missing tables

sql_files = %i[bypass_migrations moh_regimens_v2021 spine_adaptaion]

sql_files.each do |file|
  sql = File.read("db/sql/spine/#{file}.sql")
  statements = sql.split(/;[\r\n]+/)
  statements.each do |statement|
    next if statement.strip.empty?

    ActiveRecord::Base.connection.execute(statement)
  end
end

# Set site to queens
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = '614' WHERE `property` = 'current_health_center_id';")
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'Queen Elizabeth Central Hospital' WHERE `property` = 'current_health_center_name';")
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'use.user.selected.activities';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'use.filing.number';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'use.extended.staging.questions';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'simple_application_dashboard';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'demographics.middle_name';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'demographics.visit_home_for_treatment';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'demographics.sms_for_TB_therapy';
# UPDATE `global_property` SET `property_value` = 'true' WHERE `property` = 'demographics.ground_phone';
ActiveRecord::Base.connection.execute("UPDATE `global_property` SET `property_value` = 'QECH' WHERE `property` = 'site_prefix';")
# UPDATE `global_property` SET `property_value` = 'false' WHERE `property` = 'create.from.remote';

# Update program ID
ActiveRecord::Base.connection.execute('UPDATE encounter SET program_id = 31;')
User.where(user_id: 1).update(person_id: 1)

