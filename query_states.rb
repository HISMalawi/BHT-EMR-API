hiv_program = Program.find_by_name('HIV PROGRAM')
patient_states = PatientState.joins(:patient_program).where(patient_programs: { program_id: hiv_program.id })
state_ids = patient_states.pluck(:state).uniq
states = ProgramWorkflowState.where(program_workflow_state_id: state_ids).includes(concept: :concept_names)
states.each do |s|
  puts "State ID: #{s.id}, Concepts: #{s.concept.concept_names.map(&:name).join(', ')}"
end
