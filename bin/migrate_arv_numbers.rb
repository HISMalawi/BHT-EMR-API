arv_numbers = PatientIdentifier.where(type: PatientIdentifierType.find_by_name('ARV Number'))
SITE_PREFIX = GlobalProperty.find_by_property('site_prefix').property_value

puts '==================================='
puts "Migrating ARV Numbers to prefix #{SITE_PREFIX}-ARV-XXXX"
puts '==================================='

arv_numbers.each do |arv_number|
    identifier = arv_number.identifier # KCH-ARV-82
    
    # get the number from the identifier
    number = identifier.split('-')[2]
    arv_number.update(identifier: "#{SITE_PREFIX}-ARV-#{number}")
end


puts '==================================='
puts 'Done!'
puts '==================================='