# frozen_string_literal: true

require 'yaml'
require 'digest/sha1'
require 'securerandom'

# -------------------------------------------------------------------
# Load database configuration
# -------------------------------------------------------------------

db_config = YAML.load_file(
  Rails.root.join('config', 'database.yml'),
  aliases: true
)[Rails.env]

username = db_config['username']
password = db_config['password']
database = db_config['database']
host     = db_config['host']
port     = db_config['port']

# -------------------------------------------------------------------
# Load OpenMRS skeleton database
# -------------------------------------------------------------------

cmd = "gunzip -c db/mahis_skeleton.sql.gz | mysql -u #{username}"
cmd += " -p#{password}" if password.present?
cmd += " -h #{host}" if host.present?
cmd += " -P #{port}" if port.present?
cmd += " #{database}"

system(cmd)

puts 'Harmonized DB Initialization Complete 🎉'

# -----------------------------------------------------------
# loop through db/data, get all .sql.gz and import them
# -----------------------------------------------------------
files = Dir.glob(Rails.root.join('db', 'data', '*.sql.gz'))
total = files.size

files.each_with_index do |file_path, idx|
  puts "Importing file #{idx + 1}/#{total}: #{File.basename(file_path)}..."
  cmd = "gunzip -c #{file_path} | mysql -u #{username}"
  cmd += " -p#{password}" if password.present?
  cmd += " -h #{host}" if host.present?
  cmd += " -P #{port}" if port.present?
  cmd += " #{database}"

  system(cmd)

  puts "Imported data from #{File.basename(file_path)}"
end

conn = ActiveRecord::Base.connection

# -------------------------------------------------------------------
# Disable FK checks (SAFE: fresh database bootstrap)
# -------------------------------------------------------------------

conn.execute 'SET FOREIGN_KEY_CHECKS = 0;'

begin
  # ================================================================
  # 0. Locations loaded from locations.sql.gz
  # ================================================================
  # All location data (1,930 facilities with IDs 1-1930) loaded from dump file
  # Schema includes TINYINT(1) columns for voided/retired

  puts 'Location data loaded from locations.sql.gz (1,930 facilities with IDs 1-1930).'

  # ================================================================
  # 1. Bootstrap SYSTEM (daemon) user — user_id = 1
  # ================================================================

  system_person_uuid = SecureRandom.uuid

  conn.execute <<~SQL
    INSERT INTO person
      (gender, creator, date_created, voided, uuid)
    VALUES
      ('U', 1, NOW(), 0, '#{system_person_uuid}');
  SQL

  system_person_id = conn.select_value <<~SQL
    SELECT person_id FROM person WHERE uuid = '#{system_person_uuid}'
  SQL

  # Password: daemon
  system_salt = SecureRandom.base64
  system_password_hash = Digest::SHA1.hexdigest("#{system_salt}daemon")

  conn.execute('TRUNCATE TABLE users;')

  conn.execute <<~SQL
    INSERT INTO users
      (
        user_id,
        username,
        password,
        salt,
        person_id,
        creator,
        date_created,
        retired,
        uuid,
        location_id
      )
    VALUES
      (
        1,
        'daemon',
        '#{system_password_hash}',
        '#{system_salt}',
        #{system_person_id},
        1,
        NOW(),
        0,
        UUID(),
        1
      );
  SQL

  # ================================================================
  # 2. Create ADMIN person
  # ================================================================

  admin_person_uuid = SecureRandom.uuid

  conn.execute <<~SQL
    INSERT INTO person
      (gender, creator, date_created, voided, uuid)
    VALUES
      ('M', 1, NOW(), 0, '#{admin_person_uuid}');
  SQL

  admin_person_id = conn.select_value <<~SQL
    SELECT person_id FROM person WHERE uuid = '#{admin_person_uuid}'
  SQL

  conn.execute <<~SQL
    INSERT INTO person_name
      (
        person_id,
        given_name,
        family_name,
        preferred,
        creator,
        date_created,
        voided,
        uuid
      )
    VALUES
      (
        #{admin_person_id},
        'Admin',
        'User',
        1,
        1,
        NOW(),
        0,
        UUID()
      );
  SQL

  # ================================================================
  # 3. Create ADMIN user
  # ================================================================

  # Use a more secure random salt
  admin_salt = SecureRandom.base64
  admin_password = 'Admin123'
  admin_password_hash = Digest::SHA1.hexdigest("#{admin_password}#{admin_salt}")

  conn.execute <<~SQL
    INSERT INTO users
      (
        username,
        password,
        salt,
        person_id,
        creator,
        date_created,
        retired,
        uuid,
        location_id
      )
    VALUES
      (
        'admin',
        '#{admin_password_hash}',
        '#{admin_salt}',
        #{admin_person_id},
        1,
        NOW(),
        0,
        UUID(),
        1
      );
  SQL

  admin_user_id = conn.select_value <<~SQL
    SELECT user_id FROM users WHERE username = 'admin'
  SQL

  # ================================================================
  # 4. Assign SYSTEM DEVELOPER role
  # ================================================================

  conn.execute <<~SQL
    INSERT INTO user_role (user_id, role)
    VALUES (#{admin_user_id}, 'System Developer');
  SQL

  # ================================================================
  # 5. Create UserProperty records for password management
  # ================================================================

  # Get system user ID
  system_user_id = conn.select_value <<~SQL
    SELECT user_id FROM users WHERE username = 'daemon'
  SQL

  # Set last_password_updated for both users (current timestamp)
  [system_user_id, admin_user_id].each do |user_id|
    conn.execute <<~SQL
      INSERT INTO user_property
        (user_id, property, property_value)
      VALUES
        (#{user_id}, 'last_password_updated', '#{Time.now.iso8601}');
    SQL
  end

  puts 'User properties created for password management.'
ensure
  # -----------------------------------------------------------------
  # Re-enable FK checks (CRITICAL)
  # -----------------------------------------------------------------
  conn.execute 'SET FOREIGN_KEY_CHECKS = 1;'
end

puts <<~MSG
  ----------------------------------------
  OpenMRS initialization complete
  ----------------------------------------
  System user:
    username: daemon
    password: daemon

  Admin user:
    username: admin
    password: Admin123
    role:     System Developer
  ----------------------------------------
MSG
