# frozen_string_literal: true

require 'rake'

namespace :streaming do
  desc "Setup streaming"
  task setup: :environment do
    # verify queue config has been setup in database.yml
    unless Rails.configuration.database_configuration[Rails.env]['queue']
      puts "Please setup queue config in database.yml"
      puts "See database.yml.example for details on queue configuration" 
      exit 1
    end

    # copy queue.yml and recurring.yml example files if not already
    unless File.exist?(Rails.root.join('config', 'queue.yml'))
      FileUtils.cp Rails.root.join('config', 'queue.yml.example'), Rails.root.join('config', 'queue.yml')
    end

    unless File.exist?(Rails.root.join('config', 'recurring.yml'))
      FileUtils.cp Rails.root.join('config', 'recurring.yml.example'), Rails.root.join('config', 'recurring.yml')
    end

    # check for queue configs in application.yml
    unless YAML.load_file(Rails.root.join('config', 'application.yml'))['cdr']
      puts "Please setup queue config in application.yml"
      puts "See application.yml.example for details on cdr key configuration" 
      exit 1
    end

    # create queue database if not exists
    Rake::Task['db:create:queue'].invoke

    # load schema
    Rake::Task['db:schema:load:queue'].invoke unless SolidQueue::Job.table_exists?

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