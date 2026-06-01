defaulted_concept = Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }).first
default_state_id = ProgramWorkflowState.find_by_concept_id(defaulted_concept&.id)&.id
puts "Seed used ID: #{default_state_id}"

patient_states = PatientState.all.pluck(:state).uniq
puts "States in DB: #{patient_states.inspect}"

