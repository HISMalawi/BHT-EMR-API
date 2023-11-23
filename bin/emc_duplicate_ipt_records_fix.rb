# frozen_string_literal: true

def duplicate_ipt_records
  ActiveRecord::Base.connection.select_all <<~SQL
    SELECT o.concept_id, o.patient_id, GROUP_CONCAT(o.encounter_id) encounters, GROUP_CONCAT(dor.drug_inventory_id) drugs, GROUP_CONCAT(o.order_id) orders, o.start_date
    FROM orders o
    INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
    WHERE o.concept_id IN (#{ConceptName.where(name: ['Pyridoxine', 'Isoniazid/Rifapentine', 'Rifapentine', 'Isoniazid'], concept_name_type: 'FULLY_SPECIFIED').select(:concept_id).to_sql})
    AND o.voided = 0
    GROUP BY o.patient_id, DATE(o.start_date), o.concept_id HAVING count(o.concept_id) > 1
  SQL
end

def concept_name_id(name)
  ConceptName.find_by_name(name).concept_id
end

def concept_name(concept_id)
  ConceptName.find_by_concept_id(concept_id).name
end

def arv_number(patient_id)
  PatientIdentifier.where(patient_id: patient_id,
                          identifier_type: PatientIdentifierType.find_by_name('ARV NUMBER').id)&.first&.identifier
end

def patient_weight(patient_id, duplicate_date)
  Observation.where('person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= DATE(?)', patient_id,
                    concept_name_id('WEIGHT (KG)'), duplicate_date).order('obs_datetime DESC')&.first&.value_numeric
end

def valid_prescription(duplicate_record)
  weight = patient_weight(duplicate_record['patient_id'], duplicate_record['start_date'])
  concept_name = concept_name(duplicate_record['concept_id'])
  prescription = regimen_engine.regimen_extras(weight, concept_name)
  prescription.blank? ? nil : prescription[0][:drug_id]
end

def regimen_engine
  @regimen_engine ||= ARTService::RegimenEngine.new(program: Program.find_by_name('HIV PROGRAM').id)
end

def process
  duplicate_ipt_records.each do |duplicate_record|
    puts "Processing #{duplicate_record['patient_id']} and orders #{duplicate_record['orders']} on #{duplicate_record['start_date']}"
    prescription = valid_prescription(duplicate_record)
    prescription.blank? ? abnormal_process(duplicate_record) : normal_process(duplicate_record, prescription)
  end
end

def abnormal_process(duplicate_record)
  puts 'abnormal process'
  @skipped.puts "#{duplicate_record['patient_id']}, #{arv_number(duplicate_record['patient_id'])}, #{duplicate_record['start_date']}, #{concept_name(duplicate_record['concept_id'])}"
end

def normal_process(duplicate_record, prescription)
  puts 'normal process'
  orders = duplicate_record['orders'].split(',')

  # find the index of the drug that matches the prescription
  drug_index = duplicate_record['drugs'].split(',').index(prescription.to_s)

  # void all the orders except the index of the drug that matches the prescription
  process_orders(orders, drug_index)

  @file.puts "#{duplicate_record['patient_id']}, #{arv_number(duplicate_record['patient_id'])}, #{duplicate_record['start_date']}, #{concept_name(duplicate_record['concept_id'])}"
end

def process_orders(orders, drug_index)
  orders.each_with_index do |order, index|
    next if index == drug_index

    order = Order.where(order_id: order)&.first
    void_obs(order.observations) unless order.blank?
    order.void('Duplicate IPT record') unless order.blank?
  end
end

def void_obs(obs)
  obs.each { |o| o.void('Duplicate IPT record') }
end

def prepare_files
  @file = File.new("emc_ipt_duplicates_#{Time.now.strftime('%Y%m%d')}.csv", 'w+')
  @skipped = File.new("emc_ipt_duplicates_skipped_#{Time.now.strftime('%Y%m%d')}.csv", 'w+')
  @skipped.puts 'patient_id, arv_number, start_date, drug_name'
  @file.puts 'patient_id, arv_number, start_date, drug_name'
end

def close_files
  @file.close
  @skipped.close
end

def main
  User.current = User.first
  Location.current = Location.find(GlobalProperty.find_by(property: 'current_health_center_id').property_value)
  prepare_files
  process
  close_files
end

main
