# frozen_string_literal: true

puts 'Adding user programs...'
User.find_by(username: 'admin').update(location_id: 'LL040010')
UserRole.find_by(user_id: 1).update(role: Role.find_by(role: 'Superuser,Superuser,'))
Program.all.each do |p|
  puts "Adding user program for #{p.name}"
  UserProgram.find_or_create_by!(user_id: 1, program_id: p.id)
end
