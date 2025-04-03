tb_numbers = PatientIdentifier.where(type: PatientIdentifierType.find_by_name('District TB Number'))
SITE_PREFIX = GlobalProperty.find_by_property('site_prefix').property_value

puts '==================================='
puts "Migrating TB Numbers to prefix #{SITE_PREFIX}/TB/XXXX"
puts '==================================='

tb_numbers.each do |tb_number|
    identifier = tb_number.identifier # MPC/TB/78/yy
    
    # get the number from the identifier
    number = identifier.split('/')[2]
    #update the identifier
    tb_number.update(identifier: "#{SITE_PREFIX}/TB/#{number}/#{year}")
end


puts '==================================='
puts 'Done!'
puts '==================================='