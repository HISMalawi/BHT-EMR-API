# lib/tasks/import_facilities.rake
# rails import:facilities
# rails import:facilities:rollback
namespace :import do
  desc "Import facilities from JSON file with validation, backup, and data transformation"
  task facilities: :environment do
    require 'json'
    require 'fileutils'

    class FacilityImporter
      def initialize
        @json_file_path = Rails.root.join('db', 'data', 'facilities', 'facilities.json')
        @backup_dir = Rails.root.join('db', 'data', 'facilities', 'backups')
        @total = 0
        @imported = 0
        @failed = 0
        @validation_warnings = []
      end

      def perform
        validate_file_exists
        create_backup
        import_facilities
        display_results
      rescue StandardError => e
        puts "\nCritical Error: #{e.message}"
        restore_from_backup if @backup_path
      end

      private

      def validate_file_exists
        unless File.exist?(@json_file_path)
          raise "File not found at #{@json_file_path}"
        end
      end

      def create_backup
        FileUtils.mkdir_p(@backup_dir)
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        @backup_path = File.join(@backup_dir, "facilities_backup_#{timestamp}.json")
        @db_backup_path = File.join(@backup_dir, "db_backup_#{timestamp}.json")
        FileUtils.cp(@json_file_path, @backup_path)
        puts "Backup created at #{@backup_path}"

        # Database backup - backup locations with their attributes
        backup_data = []
        Location.includes(:location_attributes).find_each do |location|
          backup_data << {
            location: location.attributes,
            attributes: location.location_attributes.map(&:attributes)
          }
        end
        
        File.write(@db_backup_path, backup_data.to_json)
        puts "Database backup created at #{@db_backup_path}"
      end

      def restore_from_backup
        puts "\nAttempting to restore from backup..."
        FileUtils.cp(@backup_path, @json_file_path)
        puts "Restored from #{@backup_path}"
      end

      def parse_date(date_string)
        return nil if date_string.blank?

        # Handle various date formats by removing ordinals and parsing
        date_string = date_string.gsub(/(st|nd|rd|th)/, '') # Remove ordinals

        begin
          if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)
            Date.parse(date_string)
          else
            # Handle formats like "Jan 1 75" or "1st Jan 1975"
            Date.parse(date_string).strftime('%Y-%m-%d')
          end
        rescue Date::Error
          @validation_warnings << "Invalid date format: #{date_string}"
          nil
        end
      end

      def validate_facility_data(data)
        warnings = []
        warnings << "Missing code" if data['code'].blank?
        warnings << "Missing name" if data['name'].blank?
        
        # For longitude and latitude, we'll just log warnings instead of blocking import
        if data['latitude'].present? && !valid_latitude?(data['latitude'])
          warnings << "Invalid latitude: #{data['latitude']}"
        end
        
        if data['longitude'].present? && !valid_longitude?(data['longitude'])
          warnings << "Invalid longitude: #{data['longitude']}"
        end
        
        warnings
      end

      def valid_latitude?(latitude)
        latitude.to_s.match?(/^-?([1-8]?[0-9](\.\d+)?|90(\.0+)?)$/) # Latitude range -90 to 90
      end

      def valid_longitude?(longitude)
        longitude.to_s.match?(/^-?([1-9]?[0-9]{1,2}(\.\d+)?|180(\.0+)?)$/) # Longitude range -180 to 180
      end

      def transform_facility_data(data)
        # Data for the location table
        location_data = {
          name: clean_string(data['name']),
          city_village: clean_string(data['district'])
        }

        # Only add latitude and longitude if they are valid
        location_data[:latitude] = clean_string(data['latitude']) if valid_latitude?(data['latitude'])
        location_data[:longitude] = clean_string(data['longitude']) if valid_longitude?(data['longitude'])

        # Data for location_attributes table
        attributes_data = {
          code: clean_string(data['code']),
          common: clean_string(data['common']),
          ownership: clean_string(data['ownership']),
          facility_type: clean_string(data['type']),
          status: clean_string(data['status']),
          regulatory_status: clean_string(data['regulatoryStatus']),
          date_opened: parse_date(data['dateOpened'])
        }

        { location: location_data, attributes: attributes_data }
      end

      def clean_string(value)
        value.to_s.strip # Trim leading and trailing spaces
      end

      def get_attribute_type_id(name)
        @attribute_type_ids ||= {}
        @attribute_type_ids[name] ||= ActiveRecord::Base.connection.execute(
          "SELECT location_attribute_type_id FROM location_attribute_type WHERE name = '#{name}' LIMIT 1"
        ).first&.first
      end

      def find_location_by_code(code)
        # Find location that has a location_attribute with attribute_type 'Facility Code' and value_reference=code
        facility_code_type_id = get_attribute_type_id('Facility Code')
        location_attribute = LocationAttribute.find_by(attribute_type_id: facility_code_type_id, value_reference: code)
        location_attribute&.location
      end

      def save_location_attributes(location_id, attributes_data)
        # Save or update each attribute using named references
        save_or_update_attribute(location_id, 'Facility Code', attributes_data[:code]) if attributes_data[:code].present?
        save_or_update_attribute(location_id, 'Facility Common Name', attributes_data[:common]) if attributes_data[:common].present?
        save_or_update_attribute(location_id, 'Facility Ownership', attributes_data[:ownership]) if attributes_data[:ownership].present?
        save_or_update_attribute(location_id, 'Facility Type', attributes_data[:facility_type]) if attributes_data[:facility_type].present?
        save_or_update_attribute(location_id, 'Facility Status', attributes_data[:status]) if attributes_data[:status].present?
        save_or_update_attribute(location_id, 'Facility Regulatory Status', attributes_data[:regulatory_status]) if attributes_data[:regulatory_status].present?
        save_or_update_attribute(location_id, 'Facility Date Opened', attributes_data[:date_opened]) if attributes_data[:date_opened].present?
      end

      def save_or_update_attribute(location_id, attribute_type_name, value)
        attribute_type_id = get_attribute_type_id(attribute_type_name)
        attribute = LocationAttribute.find_or_initialize_by(
          location_id: location_id,
          attribute_type_id: attribute_type_id
        )
        attribute.value_reference = value
        attribute.creator = 1 if attribute.new_record?
        attribute.date_created = Time.current if attribute.new_record?
        attribute.voided = 0
        attribute.save!
      end

      def import_facilities
        puts "Starting facility import..."

        # Read and parse JSON
        json_content = JSON.parse(File.read(@json_file_path))
        facilities_data = json_content['data']
        @total = facilities_data.length

        # Wrap in transaction
        ActiveRecord::Base.transaction do
          facilities_data.each_with_index do |facility_data, index|
            import_facility(facility_data, index + 1)
          end

          # Raise an error if too many failures
          failure_threshold = 0.3 # 30%
          if @failed.to_f / @total > failure_threshold
            raise "Too many failures (#{@failed} out of #{@total}). Rolling back."
          end
        end
      end

      def import_facility(facility_data, index)
        # Validate data
        validation_warnings = validate_facility_data(facility_data)
        
        begin
          # Transform data
          transformed_data = transform_facility_data(facility_data)
          code = clean_string(facility_data['code'])

          # Use a transaction to ensure atomicity
          Location.transaction do
            # Find existing location by code attribute or create new
            location = find_location_by_code(code) || Location.new
            
            # Assign location attributes
            location.assign_attributes(transformed_data[:location])
            location.creator = 1 if location.new_record? # Set default creator
            
            if location.save
              # Save location attributes
              save_location_attributes(location.location_id, transformed_data[:attributes])
              
              @imported += 1
              
              # Log any validation warnings for this facility
              if validation_warnings.any?
                @validation_warnings << "Facility #{code}: #{validation_warnings.join(', ')}"
              end
              
              print '.' if index % 10 == 0
            else
              @failed += 1
              @validation_warnings << "Facility #{code}: #{location.errors.full_messages.join(', ')}"
              raise ActiveRecord::Rollback
            end
          end

        rescue => e
          @failed += 1
          @validation_warnings << "Facility #{facility_data['code']}: #{e.message}"
        end
      end

      def display_results
        puts "\n\nImport Summary:"
        puts "Total facilities in file: #{@total}"
        puts "Successfully imported/updated: #{@imported}"
        puts "Failed: #{@failed}"

        if @validation_warnings.any?
          puts "\nWarnings encountered:"
          @validation_warnings.each { |warning| puts "- #{warning}" }
        end

        puts "\nFile backup location: #{@backup_path}"
        puts "Database backup location: #{@db_backup_path}"
      end
    end

    # Run the import
    FacilityImporter.new.perform
  end

  desc "Rollback last facilities import using backup"
  task rollback_facilities: :environment do
    backup_dir = Rails.root.join('db', 'data', 'facilities', 'backups')
    latest_backup = Dir.glob(File.join(backup_dir, 'db_backup_*.json')).max_by { |f| File.mtime(f) }

    if latest_backup
      puts "Rolling back to backup: #{latest_backup}"
      
      # Parse backup data
      backup_data = JSON.parse(File.read(latest_backup))
      
      ActiveRecord::Base.transaction do
        # Clear existing location attributes for facilities
        location_ids = backup_data.map { |item| item['location']['location_id'] }.compact
        
        # Get attribute type IDs by name
        attribute_type_ids = [
          'Facility Code', 'Facility Common Name', 'Facility Ownership', 'Facility Type',
          'Facility Status', 'Facility Regulatory Status', 'Facility Date Opened'
        ].map { |name| ActiveRecord::Base.connection.execute(
          "SELECT location_attribute_type_id FROM location_attribute_type WHERE name = '#{name}' LIMIT 1"
        ).first&.first }.compact
        
        LocationAttribute.where(location_id: location_ids, attribute_type_id: attribute_type_ids).delete_all
        
        # Clear locations
        Location.where(location_id: location_ids).delete_all

        # Restore from backup
        backup_data.each do |item|
          location = Location.create!(item['location'])
          
          # Restore location attributes
          item['attributes'].each do |attr|
            LocationAttribute.create!(attr)
          end
        end
      end

      puts "Rollback completed successfully"
    else
      puts "No backup found in #{backup_dir}"
    end
  end
end