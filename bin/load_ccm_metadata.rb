


ConceptNames = [
  'Ever had CxCa', 'Offer CxCa', 'CxCa test results', 'CxCa test date',
  'Suspect', 'Thermocoagulation', 'Postponed treatment', 'Client NOT ready',
  'Treatment NOT available', 'Unable to treat client',  'Chemotherapy',
  'Leep', 'Thermo','Cancer confirmed','CxCa program', 'Pre CxCa treatment',
  'Preferred counseling','Reason for NOT offering CxCa','CxCa treatment',
  'Postponed reason','Referral location','Previous CxCa location',
  'Previous CxCa results', 'Cancer treatment', 'Cancer treatment procedure',
  'Post CxCa assessment','Positive on ART','Positive NOT on ART',
  'Negative tested <1 year', 'VIA','HPV DNA','Speculum Exam',
  'PAP Smear normal','PAP Smear abnormal','HPV negative','HPV positive',
  'Visible Lesion','No visible Lesion','Same day treatment',
  'Large Lesion (>75%)','Further Investigation & Management',
  'Suspect cancer','Referral feedback','One year subsequent check-up after treatment',
  'Initial Screening','Subsequent screening',
  'Problem visit after treatment','CxCa screening method','Previous CxCa screening method',
  'Screening results','VIA negative', 'VIA positive'
]

CxCaEncounters = [
  'CxCa test','CxCa treatment','CxCa reception',
  'CxCa referral feedback', 'CxCa results', 'CxCa screening result'
 ]

def cervical_cancer_metadata

  ConceptNames.map do |concept_name|
    concept = Concept.create(datatype_id: 4, class_id: 5, creator: 1,
      date_created:  Time.now(), uuid: SecureRandom.uuid)

    ConceptName.create(name: concept_name, concept_id: concept.id, creator: 1,
      locale: 'en', date_created: Time.now(), uuid:  SecureRandom.uuid)

    puts  "--> #{concept_name}"
  end


  CxCaEncounters.each do |enc|
    EncounterType.create(name: enc, creator: 1, date_created: Time.now(),
      uuid: SecureRandom.uuid)
  end

  program = Program.create(name: 'CxCa program', concept_id: ConceptName.find_by(name: 'CxCa program').concept_id,
    creator: 1, uuid: SecureRandom.uuid, date_changed: Time.now(), changed_by: 1)

  program_workflow = ProgramWorkflow.create(program_id: program.program_id, creator: 1,
    date_changed: Time.now(), concept_id: 1484, changed_by: 1, date_created: Time.now(), uuid: SecureRandom.uuid)
  puts "###########-> #{program_workflow.program_id}  ---  #{program_workflow.retired}"



  states = ['Pre CxCa treatment','Chemotherapy',
    'Leep', 'Thermo',
    'Cancer confirmed', 'Other gynaecological condition',
    'Patient died','Treatment complete','Post CxCa assessment']

  states.each do |st|
    puts "--------->> #{st}"
    concept_state = ConceptName.find_by(name: st)
    initial = (st == 'Pre CxCa treatment' ? 1 :  0)

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
