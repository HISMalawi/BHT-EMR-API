User.current = User.first || User.new(user_id: 1)
Location.current = Location.first || Location.new(location_id: 1)

hiv_program = Program.find_by_name('HIV PROGRAM')

defaulted_concept = Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }).first
default_state_id = ProgramWorkflowState.find_by_concept_id(defaulted_concept&.id)&.id

programs = PatientProgram.where(program_id: hiv_program.id).to_a
programs.shuffle!

half = programs.size / 2
defaulted_programs = programs[0...half]

puts "Assigning default states to #{defaulted_programs.size} programs..."

defaulted_programs.each do |pp|
  # Delete the latest state if it exists just to cleanly append this state
  ps = PatientState.new(
        patient_program_id: pp.id, 
        state: default_state_id, 
        start_date: 1.month.ago.to_date
      )
  unless ps.save(validate: false)
    puts "Failed to save! Errors: #{ps.errors.full_messages}"
  end
end

puts "Success! States assigned."
