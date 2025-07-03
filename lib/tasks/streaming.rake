# frozen_string_literal: true

require 'rake'

namespace :streaming do
  desc "Setup streaming"
  task setup: :environment do

    # set database to primary to prevent rails from using queue database
    # when running rake tasks
    system("export DATABASE=primary")

    # verify queue config has been setup in database.yml
    unless Rails.configuration.database_configuration[Rails.env]['queue']
      puts "Please setup queue config in database.yml"
      puts "See database.yml.example for details on queue configuration" 
      exit 1
    end

    # copy queue.yml and recurring.yml example files if not already
    unless File.exist?(Rails.root.join('config', 'queue.yml'))
      FileUtils.cp Rails.root.join('config', 'queue.yml.example'), Rails.root.join('config', 'queue.yml')
      
      puts "Copied queue.yml and recurring.yml example files to config directory."
    end

    unless File.exist?(Rails.root.join('config', 'recurring.yml'))
      FileUtils.cp Rails.root.join('config', 'recurring.yml.example'), Rails.root.join('config', 'recurring.yml')

      puts "Copied queue.yml and recurring.yml example files to config directory."
    end

    # check for queue configs in application.yml
    unless YAML.load_file(Rails.root.join('config', 'application.yml'))['cdr']
      puts "Please setup queue config in application.yml"
      puts "See application.yml.example for details on cdr key configuration" 
      exit 1
    end

    # check if queue database exists, if not create it
    ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1' if Rails.env.production?

    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'queue')

    abort "Missing 'queue' DB config under #{Rails.env} in database.yml" unless config

    ActiveRecord::Tasks::DatabaseTasks.create(config)

    # Connect to queue database before checking for schema
    ActiveRecord::Base.establish_connection(:queue)
    
    unless SolidQueue::Process.table_exists?
      puts 'Loading schema for queue DB...'
      ActiveRecord::Tasks::DatabaseTasks.load_schema(config, :ruby, "#{Rails.root}/db/queue_schema.rb")
    end
    
    ActiveRecord::Base.establish_connection(:primary)

    # Enable Streaming in Global Properties
    use_db = <<~SQL
      USE #{Rails.configuration.database_configuration[Rails.env]['primary']['database']};
    SQL
    query = <<~SQL
      INSERT INTO global_property (uuid, property, property_value, description)
      VALUES (UUID(), 'patient.streaming', 'active', 'Enable/Disable patient streaming')
      ON DUPLICATE KEY UPDATE property_value = 'active';
    SQL
    ActiveRecord::Base.connection.execute(use_db)
    ActiveRecord::Base.connection.execute(query)

    # success message
    puts "\e[32mStreaming setup successfully\e[0m"
  
  rescue => e
    puts "\e[31mStreaming setup failed\e[0m"
    puts e.message
  end
end