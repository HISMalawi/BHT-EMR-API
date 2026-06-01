begin
  default_state_id = 30
  program_start = 1.month.ago
  patient_program = PatientProgram.first

  ps = PatientState.new(
    patient_program_id: patient_program.id, 
    state: default_state_id, 
    start_date: program_start
  )
  ps.save(validate: false)
rescue => e
  puts e.message
end
