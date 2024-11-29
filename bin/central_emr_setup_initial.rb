# # dump initial database
config = YAML.load_file(Rails.root.join('config', 'database.yml'), aliases: true)[Rails.env]

USERNAME = config['username']
PASSWORD = config['password']
HOST = config['host']
PORT = config['port']
DB = User.connection.current_database

def cmd(command)
  system(command)
end

def load_sql(file)
  command = "mysql --host #{HOST} --port #{PORT} -u #{USERNAME} -p#{PASSWORD} #{DB} < #{file} -f"
  cmd(command)
end

begin
  cmd("bash #{Rails.root.join('bin', 'initial_database_setup.sh')} #{Rails.env} defaults")
rescue StandardError => e
  puts e
  nil
end

metadata = File.join(Rails.root, 'db', 'sql', 'openmrs_metadata_1_7.sql')
load_sql(metadata)


Dir[Rails.root.join('db/migrate/*.rb')].each do |file|
  begin
    next unless file.end_with?('.rb')
    
    version = File.basename(file).split('_').first.to_i
    puts "Running migration: #{file}"
    
    migration = ActiveRecord::MigrationContext.new(
      Rails.root.join('db/migrate'), 
      ActiveRecord::Base.connection.schema_migration
      )

    migration.migrate(version)
  rescue => e
    puts "Migration failed: #{file}, error: #{e.message}"
    next
  end
end

User.first.update_attributes(
  site_id: 1
)&.save!




