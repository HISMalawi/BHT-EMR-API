default_state_id = 30
program_start = 1.month.ago
patient_program = PatientProgram.first

ps = PatientState.new(
  patient_program_id: patient_program.id, 
  state: default_state_id, 
  start_date: program_start
)
saved = ps.save(validate: false)
puts "Saved? #{saved}"
if !saved
  puts "Errors: #{ps.errors.full_messages}"
end
