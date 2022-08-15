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
  Lab::OrdersService.order_test(prepare_order_payload(obs))
end

def create_test(obs, order)
  test = Observation.where(encounter_id: order['encounter_id']).first
  Lab::ResultsService.create_results(test.id, prepare_test_payload(obs, order), 'user entered')
end

def void_obs(obs, order)
  result = Observation.where(encounter_id: order['encounter_id'], concept_id: concept_name('Viral load')).first.id
  puts "Voiding old result #{obs.id} and creating result #{result}"
  write_to_text_file("#{obs.id},#{result}")
  if obs.encounter.type.name == 'LAB'
    obs.encounter.void("copied to #{order['encounter_id']}")
  else
    obs.void("copied to #{result}")
  end
end

def write_to_text_file(content)
  @file.puts content
end

def prepare_order_payload(obs)
  provider = obs.encounter.provider_id
  { patient_id: obs.person_id, provider_id: provider, date: obs.obs_datetime, program_id: program,
    tests: [{ concept_id: concept_name('Viral Load') }], specimen: { concept_id: concept_name('Blood') },
    requesting_clinician: User.where(person_id: provider)&.first&.username, reason_for_test_id: concept_name('Unknown'),
    target_lab: Location.current.name }
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
  @file.puts 'obs_old_id,obs_new_id'
  process
  @file.close
end

main
