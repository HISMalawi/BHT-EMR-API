tb_numbers = PatientIdentifier.where(type: PatientIdentifierType.find_by_name('District TB Number'))
SITE_PREFIX = GlobalProperty.find_by_property('site_prefix').property_value

puts '==================================='
puts "Migrating TB Numbers to prefix #{SITE_PREFIX}/TB/XXXX/YYYY"
puts '==================================='

tb_numbers.each do |tb_number|
  identifier = tb_number.identifier # Example: MPC/TB/78/2016

  # Extract the number and year from the identifier
  parts = identifier.split('/')
  if parts.length < 4
    puts "Invalid identifier format: #{identifier}. Skipping..."
    next
  end

  number = parts[2]
  year = parts[3]

  # Update the identifier with the new prefix
  new_identifier = "#{SITE_PREFIX}/TB/#{number}/#{year}"
  if identifier != new_identifier
    tb_number.update(identifier: new_identifier)
    puts "Migrated: #{identifier} -> #{new_identifier}"
  else
    puts "Already migrated: #{identifier}"
  end
end

puts '==================================='
puts 'Done!'
puts '==================================='