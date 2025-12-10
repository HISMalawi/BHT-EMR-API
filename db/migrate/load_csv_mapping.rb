#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to load facility-location mapping from CSV file
# This can be run standalone or as part of the migration process

require 'csv'
require 'active_record'

# Configuration
CSV_FILE_PATH = Rails.root.join('db', 'csv', 'locations_x_facilities.csv')

def load_csv_mapping
  puts "Loading facility-location mapping from #{CSV_FILE_PATH}..."

  # Create temporary table
  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS temp_facility_x_location_map;
  SQL

  ActiveRecord::Base.connection.execute <<~SQL
    CREATE TABLE IF NOT EXISTS temp_facility_x_location_map (
        location_id INT PRIMARY KEY,
        location_name VARCHAR(255),
        location_district VARCHAR(255),
        facility_code VARCHAR(255),
        facility_name VARCHAR(255)
        )
        ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
  SQL

  # Add index on facility_code if it does not exist
  indexes = ActiveRecord::Base.connection.indexes('temp_facility_x_location_map').map(&:columns)
  unless indexes.include?(['facility_code'])
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_facility_code ON temp_facility_x_location_map(facility_code);
    SQL
  end

  # Read CSV and insert mappings
  mappings = []
  CSV.foreach(CSV_FILE_PATH, headers: true) do |row|
    location_id = row['location_id']&.to_i
    facility_code = row['facility_code']&.strip
    location_name = row['location_name']&.strip
    location_district = row['location_district']&.strip
    facility_name = row['facility_name']&.strip

    next if location_id.nil? || location_id.zero? || facility_code.nil? || facility_code.empty?

    mappings << { facility_code: facility_code, location_id: location_id, location_name: location_name,
                  location_district: location_district, facility_name: facility_name }
  end

  puts "Found #{mappings.size} mappings in CSV file"

  # Remove duplicates (keep first occurrence)
  unique_mappings = mappings.uniq { |m| m[:facility_code] }
  puts "After removing duplicates: #{unique_mappings.size} unique mappings"

  # Insert in batches
  batch_size = 1000
  unique_mappings.each_slice(batch_size) do |batch|
    values = batch.map do |m|
      "(#{ActiveRecord::Base.connection.quote(m[:facility_code])}, #{m[:location_id]}, #{ActiveRecord::Base.connection.quote(m[:location_name])}, #{ActiveRecord::Base.connection.quote(m[:location_district])}, #{ActiveRecord::Base.connection.quote(m[:facility_name])})"
    end.join(',')

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_facility_x_location_map (facility_code, location_id, location_name, location_district, facility_name)
      VALUES #{values}
      ON DUPLICATE KEY UPDATE location_id = VALUES(location_id);

    SQL
  end

  puts "Successfully loaded #{unique_mappings.size} mappings into temporary table"
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  begin
    load_csv_mapping

    # Optionally export verification file
    # export_mapping_verification

    puts "\nMapping loaded successfully!"
    puts "The temporary table 'temp_facility_x_location_map' is now available for use in migrations."
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace.join("\n")
    exit 1
  end
end
