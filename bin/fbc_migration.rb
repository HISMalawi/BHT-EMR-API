# frozen_string_literal: true

require 'csv'

# we are moving all HCT indicators of FCB to a concept 1015.
# The current references are 10532, 1243

User.current = User.first

def write_to_csv_in_log(data)
  dir = File.join(Rails.root, 'log', 'fbc_migration.csv')
  file_exists = File.exist?(dir)

  CSV.open(dir, 'a') do |csv|
    unless file_exists
      puts "Creating headers"
      csv << ['obs_id', 'order_id', 'obs_group_id', 'old_concept_id', 'new_concept_id']
    end
    csv << [data.obs_id, data.order_id, data.obs_group_id, data.concept_id, CORRECT_CONCEPT_ID]
  end
end

PROBLEMATIC_INDICATORS = [10_532, 1243].freeze
CORRECT_CONCEPT_ID = 1015
FBC_TEST = 10_062
TEST_TYPE = 9737

order_ids = Observation.where(concept_id: TEST_TYPE, value_coded: FBC_TEST).map(&:order_id).uniq
problematic_obs = Observation.where(order_id: order_ids, concept_id: PROBLEMATIC_INDICATORS)


# use threads and a minimum of 60% of the available CPUs to process this batch
queue = Queue.new
problematic_obs.each { |loc| queue << loc }

threads = Array.new(65) do
  Thread.new do
    until queue.empty?
      loc = begin
        queue.pop(true)
      rescue StandardError
        nil
      end
      next unless loc

      write_to_csv_in_log(loc)
      loc.update!(concept_id: CORRECT_CONCEPT_ID)
      puts "Processed obs: #{loc.obs_id} for order: #{loc.order_id}"
    end
  end
end

threads.each(&:join)
