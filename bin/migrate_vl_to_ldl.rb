CSV_FILE_NAME = "vl_to_ldl_migration_#{Time.now.strftime('%Y%m%d')}.csv"
HIV_PROGRAM = Program.where(name: "HIV PROGRAM").first

# all test results with 1 as value numeric and = as value_modifier for HIV program
def test_results
  Observation.joins(:encounter).where(encounter: {program: HIV_PROGRAM }, obs: {value_modifier: '=', value_numeric: 1})
end

def superuser
  User.find(1)
end

def start
  records = test_results
  @records_count = records.count
  return puts "No records to migrate" if @records_count == 0
  setup
  puts "Starting migration of #{test_results.count} test results"
  records.each do |obs|
    new_record = create_dup obs
    void_record obs
    log_record new_record, obs
    progress
  end
  cleanup
  puts "\nMigration complete"
end

def progress
  @count += 1
  STDOUT.write "\r#{@count*100/@records_count}% done"
end

def create_dup(obs)
  new_obs = obs.dup
  new_obs.value_numeric = nil
  new_obs.value_text = 'LDL'
  new_obs.value_modifier = '='
  new_obs.uuid = nil
  new_obs.creator = superuser.id
  Observation.create new_obs.attributes
end

def void_record(obs)
  obs.voided = 1
  obs.void_reason = 'Migrated to LDL'
  obs.voided_by = superuser.id
  obs.save!
end

def log_record(new_record, obs)
  #write to log file
  @file.puts "#{obs.id},#{new_record.id},#{obs.person_id},#{obs.encounter_id},#{obs.concept_id},#{obs.order_id},#{obs.value_numeric},#{obs.value_modifier}"
end

def cleanup
  @file.close
end


def setup
  #progress counter
  @count = 0
  # initialize log file
  @file = File.new(CSV_FILE_NAME, 'w+')
  @file.puts 'old_obs_id,new_obs_id,person_id,encounter_id,concept_id,order_id,value_numeric,value_modifier'
end

start rescue puts "\nMigration failed with error #{$!}"