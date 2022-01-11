# frozen_string_literal: true

require 'roo'

# method to get the clients from POC cohort
def fetch_poc_clients
  records = ActiveRecord::Base.connection.select_all <<~SQL
    SELECT
      tmp.patient_id
      # (SELECT identifier FROM patient_identifier WHERE patient_id = tmp.patient_id AND voided = 0 AND identifier_type = 3 LIMIT 1) as Nat_Id,
      # DATE_FORMAT(tmp.date_enrolled, "%d-%b-%y") as artreg_date,
      # tmp.age_at_initiation as age,
      # tmp.gender
    FROM
      temp_earliest_start_date tmp
  SQL
  @poc = records.to_a
end

# method to open a given file
def open_spreadsheet(file)
  case File.extname(file)
  when '.csv' then Csv.new(file, nil, :ignore)
  when '.xls' then Roo::Excel.new(file, nil, :ignore)
  when '.xlsx' then Roo::Excelx.new(file)
  else raise "Unknown file type: #{file}"
  end
end

# method to read the contents of mpc file
def load_imported_items(file)
  @items = []
  spreadsheet = open_spreadsheet file
  (2..spreadsheet.last_row).each do |i|
    # items << Hash[[header, spreadsheet.sheet(1).row(i)].transpose]
    @items << { 'patient_id' => spreadsheet.sheet(1).row(i)[1] }
    # 'Nat_Id' => spreadsheet.sheet(1).row(i)[0],
    # 'artreg_date' => spreadsheet.sheet(1).row(i)[2].strftime('%d-%b-%y'),
    # 'age' => spreadsheet.sheet(1).row(i)[3],
    # 'gender' => spreadsheet.sheet(1).row(i)[5] }
  end
end

# method to get patient missed by poc
def missed_by_poc
  @items - @poc
end

# method to get patients missed by mpc
def missed_by_mpc
  @poc - @items
end

# rubocop:disable Metrics/MethodLength
# method to check if there is an outcome for the missed patient
def check_outcomes
  records = missed_by_poc.map { |patient| patient['patient_id'].to_i }
  list = []
  records.each do |record|
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT count(*) as count FROM patient_state
      inner join patient_program prog on prog.patient_program_id = patient_state.patient_program_id
      where prog.patient_id = #{record}
      and prog.program_id = 1
      and patient_state.voided = 0
      and patient_state.state = 7
      and prog.voided = 0
    SQL
    list << record if result['count'].to_i.positive?
  end
  @remaining = list
  records - list
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/MethodLength
# method to check if these where ommitted because their status changed from external to new patient
def status_changed
  results = ActiveRecord::Base.connection.select_all <<~SQL
    SELECT patient_type_obs.person_id
    FROM obs AS patient_type_obs
    INNER JOIN (
      SELECT MAX(obs_datetime) AS obs_datetime, person_id
      FROM obs
      INNER JOIN encounter USING (encounter_id)
      WHERE obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Type of patient' AND voided = 0)
        AND obs.obs_datetime < DATE('2021-09-30') + INTERVAL 1 DAY
        AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'REGISTRATION' AND retired = 0)
        AND encounter.program_id IN (SELECT program_id FROM program WHERE name LIKE 'HIV Program')
        AND encounter.encounter_datetime < DATE('2021-09-30') + INTERVAL 1 DAY
        AND obs.voided = 0
        AND encounter.voided = 0
      GROUP BY obs.person_id
    ) AS max_patient_type_obs
      ON max_patient_type_obs.person_id = patient_type_obs.person_id
      AND max_patient_type_obs.obs_datetime = patient_type_obs.obs_datetime
      /* Doing the above to avoid picking patients that changed patient types at some point (eg External consultation to New patient) */
    WHERE patient_type_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
      AND patient_type_obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('Drug refill', 'External consultation') AND voided = 0)
      AND patient_type_obs.voided = 0
      AND patient_type_obs.obs_datetime < (DATE('2021-09-30') + INTERVAL 1 DAY)
    GROUP BY patient_type_obs.person_id
  SQL
  result = results.map { |record| record['person_id'].to_i }
  @check_arv = @remaining - result
  result & @remaining
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/MethodLength
# method to check those without an arv start date
def without_arv_start_date
  list = []
  @check_arv.each do |record|
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT count(*) as count FROM obs AS art_start_date_obs
      WHERE art_start_date_obs.concept_id = 2516
      AND art_start_date_obs.person_id = #{record}
      AND art_start_date_obs.voided = 0
      AND art_start_date_obs.obs_datetime < (DATE('2021-09-30')+ INTERVAL 1 DAY)
    SQL
    list << record if result['count'].to_i.positive?
  end
  @check_orders = list
  @check_arv - list
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/MethodLength
# method to check those without drug orders
def without_drug_orders
  list = []
  @check_orders.each do |record|
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT count(*) as count FROM orders AS art_order
      INNER JOIN drug_order ON drug_order.order_id = art_order.order_id
      AND drug_order.quantity > 0
      where art_order.patient_id = #{record}
      AND art_order.concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)
      AND art_order.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
      AND art_order.voided = 0
    SQL
    list << record if result['count'].to_i.positive?
  end
  @we_dont_know = list
  @check_orders - list
end
# rubocop:enable Metrics/MethodLength

# method to give us any duplicate clients being reported in the cohort
def duplicates
  a = @items.map { |record| record['patient_id'].to_i }
  a.find_all { |e| a.count(e) > 1 }.uniq.sort
end

fetch_poc_clients
load_imported_items ARGV[0]

begin
  file = File.new('mpc_verification_results.txt', 'a+')
  file.puts "Clients without a patient outcome of 'on treatment'"
  file.puts check_outcomes
  file.puts '========================================================='
  file.puts 'Client whose status changed i.e External to New patient'
  file.puts status_changed
  file.puts '========================================================='
  file.puts 'Clients without ART Start Date'
  file.puts without_arv_start_date
  file.puts '========================================================='
  file.puts 'Clients without drugs'
  file.puts without_drug_orders
  file.puts '========================================================='
  file.puts 'Undefined' unless @we_dont_know.empty?
  file.puts @we_dont_know unless @we_dont_know.empty?
  file.puts '=========================================================' unless @we_dont_know.empty?
  file.puts 'Clients not included in MPC Cohort Report List'
  file.puts(missed_by_mpc.map { |record| record['patient_id'].to_i })
  file.puts '========================================================='
  file.puts 'Duplicates found on MPC Report List'
  file.puts duplicates
rescue IOError => e
  puts e.message
ensure
  file.close unless file&.nil?
end
