hiv_program = Program.find_by_name('HIV PROGRAM')
default_state_ids = ProgramWorkflowState.joins(:concept)
                                        .merge(Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }))
                                        .pluck(:program_workflow_state_id)

defaulted = 0
active = 0

Patient.joins(:patient_programs)
      .where(patient_programs: { program_id: hiv_program.id })
      .each do |patient|
  latest_state = patient.patient_programs.find_by(program_id: hiv_program.id)
                        &.patient_states&.order(start_date: :desc)&.first
  if latest_state && default_state_ids.include?(latest_state.state)
    defaulted += 1
  else
    active += 1
  end
end

puts "Defaulted: #{defaulted}, Active: #{active}"
