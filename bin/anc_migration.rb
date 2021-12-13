# frozen_string_literal: true

require 'yaml'

# Geth the anc database name
database = YAML.load(File.open("#{Rails.root}/config/database.yml", 'r'))['anc_database']['database']

# fetch user inputs on how this script should run
what_to_run = ARGV[0].to_i

if what_to_run.zero?
  ANCService::ANCMigration.new(database).main
elsif what_to_run == 1
  ANCService::ANCReverseMigration.new({ database: database, migration_date: ARGV[1] }).main
else
  puts 'Not yet configured'
end
