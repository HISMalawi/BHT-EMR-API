


ConceptNames = [
  'Ever had VIA', 'Offer VIA', 'VIA test results', 'VIA test date',
  'Suspect', 'Thermocoagulation', 'Postponed treatment', 'Client NOT ready',
  'Treatment NOT available', 'Unable to treat client',  'Chemotherapy',
  'Leep', 'Thermo','Cancer confirmed','VIA program', 'Pre VIA treatment',
  'Preferred counseling','Reason for NOT offering VIA','VIA treatment',
  'Postponed reason','Referral location','Previous VIA location',
  'Previous VIA results'
]

VIAencounters = ['VIA test','VIA treatment']

def cervical_cancer_metadata

  ConceptNames.map do |concept_name|
    concept = Concept.create(datatype_id: 4, class_id: 5, creator: 1,
      date_created:  Time.now(), uuid: SecureRandom.uuid)

    ConceptName.create(name: concept_name, concept_id: concept.id, creator: 1,
      locale: 'en', date_created: Time.now(), uuid:  SecureRandom.uuid)

    puts  "--> #{concept_name}"
  end


  VIAencounters.each do |enc|
    EncounterType.create(name: enc, creator: 1, date_created: Time.now(),
      uuid: SecureRandom.uuid)
  end

  program = Program.create(name: 'VIA program', concept_id: ConceptName.find_by(name: 'VIA program').concept_id,
    creator: 1, uuid: SecureRandom.uuid, date_changed: Time.now(), changed_by: 1)

  program_workflow = ProgramWorkflow.create(program_id: program.program_id, creator: 1,
    date_changed: Time.now(), concept_id: 1484, changed_by: 1, date_created: Time.now(), uuid: SecureRandom.uuid)
  puts "###########-> #{program_workflow.program_id}  ---  #{program_workflow.retired}"



  states = ['Pre VIA treatment','Chemotherapy', 'Leep', 'Thermo','Cancer confirmed', 'Other gynaecological condition', 'Patient died','Treatment complete']

  states.each do |st|
    puts "--------->> #{st}"
    concept_state = ConceptName.find_by(name: st)
    initial = (st == 'Pre VIA treatment' ? 1 :  0)

    if(st == 'Died' || st == 'Treatment complete')
      terminal = 1
    else
      terminal = 0
    end

    ProgramWorkflowState.create(concept_id: concept_state.concept_id,
      program_workflow_id: program_workflow.id, initial: initial,
      terminal: terminal, creator: 1, date_created: Time.now(),
      uuid: SecureRandom.uuid)
  end

end


def lab_metadata
  program = Program.create(name: 'Laboratory program', concept_id: ConceptName.find_by(name: 'Laboratory orders').concept_id,
    creator: 1, uuid: SecureRandom.uuid, date_changed: Time.now(), changed_by: 1)

  program_workflow = ProgramWorkflow.create(program_id: program.program_id, creator: 1,
    date_changed: Time.now(), concept_id: 1484, changed_by: 1, date_created: Time.now(), uuid: SecureRandom.uuid)
  puts "###########-> #{program_workflow.program_id}  ---  #{program_workflow.retired}"



  states = ['Laboratory examinations']

  states.each do |st|
    puts "--------->> #{st}"
    concept_state = ConceptName.find_by(name: st)

    ProgramWorkflowState.create(concept_id: concept_state.concept_id,
      program_workflow_id: program_workflow.id, initial: 1,
      terminal: 1, creator: 1, date_created: Time.now(),
      uuid: SecureRandom.uuid)
  end
end


lab_metadata
cervical_cancer_metadata
