require 'date'
# Directly manipulate the DB bypassing models to assign 50% defaulted

hiv_program_id = Program.find_by_name('HIV PROGRAM').id
defaulted_concept = Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }).first
default_state_id = ProgramWorkflowState.find_by_concept_id(defaulted_concept&.id)&.id

# get patient_program_ids
program_ids = ActiveRecord::Base.connection.select_values("SELECT patient_program_id FROM patient_program WHERE program_id = #{hiv_program_id}")
program_ids.shuffle!

half = program_ids.size / 2
defaulted_ids = program_ids[0...half]

puts "Assigning default state #{default_state_id} to #{defaulted_ids.size} programs..."

defaulted_ids.each do |pp_id|
  start_date = Date.today.prev_month.strftime('%Y-%m-%d')
  sql = "INSERT INTO patient_state (patient_program_id, state, start_date, creator, date_created, uuid) VALUES (#{pp_id}, #{default_state_id}, '#{start_date}', 1, NOW(), UUID())"
  ActiveRecord::Base.connection.execute(sql)
end

puts "Success! States assigned."
