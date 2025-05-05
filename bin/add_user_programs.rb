# frozen_string_literal: true

puts 'Updating user location...'
User.find_by(username: 'admin').update(location_id: 'LL040010')
puts 'User location updated.'
puts 'Updating user role...'
UserRole.find_by(user_id: 1).update(role: Role.find_by(role: 'Superuser,Superuser,'))
puts 'User role updated.'
puts 'Adding user programs...'
Program.all.each do |p|
  puts "Adding user program for #{p.name}"
  UserProgram.find_or_create_by!(user_id: 1, program_id: p.id)
end
puts 'User programs added.'
