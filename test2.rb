default_state_ids = ProgramWorkflowState.joins(:concept)
                                        .merge(Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }))
                                        .pluck(:program_workflow_state_id)
puts "Default state ids: #{default_state_ids.inspect}"
puts "Total patient states: #{PatientState.count}"
puts "Total defaulted states: #{PatientState.where(state: default_state_ids).count}"
