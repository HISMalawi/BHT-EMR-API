# frozen_string_literal: true

def orphaned_vl_results
  Observation.where(concept_id: concept_name('Viral Load'), obs_group_id: nil).group(:encounter_id)
end

def process
  orphaned_vl_results.each do |obs|
    puts "Processing obs #{obs.id}"
    order = create_order obs
    create_test obs, order
    void_obs obs, order
  end
end

def create_order(obs)
  payload = prepare_order_payload(obs)
  Lab::OrdersService.order_test(payload)
end

def create_test(obs, order)
  test = Observation.where(encounter_id: order['encounter_id']).first
  Lab::ResultsService.create_results(test.id, prepare_test_payload(obs, order), 'user entered')
end

def void_obs(obs, order)
  result = Observation.where(encounter_id: order['encounter_id'], concept_id: concept_name('Viral load')).first.id
  puts "Voiding old result #{obs.id} and creating result #{result}"
  write_to_text_file("#{obs.id},#{result},#{obs.obs_datetime.to_date},#{order['order_date']},#{obs.person_id},#{arv_number(obs.person_id)}")
  if obs.encounter.type.name == 'LAB'
    obs.encounter.void("copied to #{order['encounter_id']}")
  else
    obs.void("copied to #{result}")
  end
end

def write_to_text_file(content)
  @file.puts content
end

def arv_number(person_id)
  PatientIdentifier.where(patient_id: person_id, identifier_type: patient_identifier_type)&.first&.identifier
end

def patient_identifier_type
  @patient_identifier_type ||= PatientIdentifierType.find_by_name('ARV Number').id
end

def prepare_order_payload(obs)
  provider = obs.encounter.provider_id
  prev_encounter = previous_visit(obs.person_id, obs.obs_datetime)
  encounter_id = create_encounter(obs, prev_encounter)['encounter_id']
  { patient_id: obs.person_id, provider_id: provider, date: prev_encounter, encounter_id: encounter_id,
    program_id: program, 'target_lab' => target_lab, reason_for_test_id: concept_name('Unknown'),
    tests: [{ concept_id: concept_name('Viral Load') }], specimen: { concept_id: concept_name('Blood') },
    'requesting_clinician' => User.where(person_id: provider)&.first&.username }
end

def previous_visit(patient_id, encounter_date)
  result = Encounter.where('patient_id = ? AND encounter_datetime < DATE(?)', patient_id,
                           encounter_date).order('encounter_datetime DESC').first
  result.blank? ? encounter_date : result.encounter_datetime
end

def prepare_test_payload(obs, order)
  text_value_present = obs.value_text&.match(/[a-zA-Z]/)
  modifier_present = obs.value_text&.scan(/(=|>|<|>=|<|<=|<>)/)&.join
  { encounter_id: order['encounter_id'], patient_id: obs.person_id, provider_id: obs.encounter.provider_id,
    date: obs.obs_datetime, comments: 'Migrating from EMC to POC',
    measures: [{ value: !text_value_present.blank? ? obs.value_text.gsub(/(=|>|<|>=|<|<=|<>)/, '') : obs.value_numeric,
                 value_type: !text_value_present.blank? ? 'text' : 'numeric',
                 value_modifier: obs.value_modifier || (modifier_present.blank? ? '=' : modifier_present[0..1]),
                 indicator: { concept_id: obs.concept_id } }] }
end

def create_encounter(obs, prev_encounter)
  Encounter.create!(
    patient_id: obs.person_id,
    program_id: obs.encounter.program_id,
    type: EncounterType.find_by_name!('LAB ORDERS'),
    encounter_datetime: prev_encounter || Date.today,
    provider_id: obs.encounter.provider_id || User.current.person.person_id
  )
end

def target_lab
  @target_lab ||= GlobalProperty.where(property: 'target.lab')&.first&.property_value || Location.where(name: 'Unknown').first.name
end

def program
  @program ||= Program.find_by_name('HIV PROGRAM').id
end

def concept_name(name)
  ConceptName.find_by_name(name).concept_id
end

def main
  User.current = User.first
  Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)
  @file = File.new("emc_poc_migration_#{Time.now.strftime('%Y%m%d')}.csv", 'w+')
  @file.puts 'obs_old_id,obs_new_id,result_date, order_date, patient_id, identifier'
  process
  @file.close
end

main
