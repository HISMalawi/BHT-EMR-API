
class ARTService::Reports::ViralLoad
  include ModelUtils

  def initialize(start_date:, end_date:)
    @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
    @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    @program = Program.find_by_name 'HIV Program'
    @possible_milestones = possible_milestones
    #global_property = GlobalProperty.find_by(property: 'use.filing.number')
    @use_filing_number = false
    #(global_property.property_value == 'true' ? true : false) rescue false
  end

  def clients_due
    global_property = GlobalProperty.find_by(property: 'use.filing.number')
    @use_filing_number = (global_property.property_value == 'true' ? true : false) rescue false

    clients =  potential_get_clients
    return [] if clients.blank?
    clients_due_list = []

    clients.each do |person|
      vl_details = get_vl_due_details(person) #person[:patient_id], person[:appointment_date], person[:start_date])
      next if vl_details.blank?
      clients_due_list << vl_details
    end

    return clients_due_list
  end

  def vl_results
    return read_results
  end

  private

  def potential_get_clients
    encounter_type = EncounterType.find_by_name 'Appointment'
    appointment_concept = ConceptName.find_by_name 'Appointment date'

    observations = Observation.where("(value_datetime BETWEEN ? AND ?) AND concept_id = ?",
      @start_date, @end_date, appointment_concept.concept_id).\
      joins("INNER JOIN encounter e ON e.encounter_id = obs.encounter_id AND e.program_id=#{@program.id}
      AND encounter_type = #{encounter_type.id}
      LEFT JOIN person p ON p.person_id = obs.person_id
      LEFT JOIN person_name n ON n.person_id = obs.person_id
      LEFT JOIN patient_identifier i ON i.patient_id = e.patient_id
      AND i.voided = 0 AND i.identifier_type = 4").group("obs.person_id").\
      order(:value_datetime).select("obs.person_id, value_datetime,
      date_antiretrovirals_started(obs.person_id, patient_start_date(obs.person_id)) start_date,
      identifier, n.given_name, n.family_name, p.birthdate, p.gender")

    return observations.map do |ob|
      {
        patient_id: ob['person_id'].to_i,
        appointment_date: ob['value_datetime'],
        start_date: ob['start_date'],
        given_name: ob['given_name'],
        family_name: ob['family_name'],
        birthdate: ob['birthdate'],
        gender: ob['gender'],
        arv_number: ob['identifier']
      }
    end
  end

  def get_vl_due_details(person) #patient_id, appointment_date, patient_start_date)
    patient_start_date = person[:start_date].to_date rescue nil
    return if patient_start_date.blank?
    start_date = patient_start_date
    appointment_date = person[:appointment_date].to_date
    months_on_art = date_diff(patient_start_date.to_date, @end_date.to_date)

    if @possible_milestones.include?(months_on_art)
      last_result = last_vl_result(person[:patient_id])
      return {
        patient_id: person[:patient_id],
        mile_stone: (patient_start_date.to_date + months_on_art.month).to_date,
        start_date: patient_start_date,
        months_on_art: months_on_art,
        appointment_date: appointment_date,
        given_name: person[:given_name],
        family_name: person[:family_name],
        gender: person[:gender],
        birthdate: person[:birthdate],
        arv_number: use_filing_number(person[:patient_id], person[:arv_number]),
        last_result: last_result[0],
        last_result_date: last_result[1]
      }
    end
  end

  def date_diff(date1, date2)
    diff_cal = ActiveRecord::Base.connection.select_one <<~SQL
    SELECT TIMESTAMPDIFF(MONTH, DATE('#{date1.to_date}'), DATE('#{date2.to_date}')) AS months;
    SQL

    return diff_cal['months'].to_i
  end

  def possible_milestones
    milestones = [6]
    start_month = 6

    1.upto(1000).each do |y|
      milestones << (start_month += 12)
    end

    return milestones
  end

  def read_results
    all_results = LaboratoryService::Reports::Clinic::ProcessedResults.new(start_date: @start_date, end_date: @end_date).read
    processed_vl_results = []

    all_results.each do |result|
    measures = result[:measures]
    measures.each do |measure|
      next unless measure[:name].match(/viral load/)
      processed_vl_results << {
        accession_number: result[:accession_number],
        result_date: result[:result_date],
        patient_id: result[:patient_id],
        order_date: result[:order_date],
        specimen: result[:test],
        gender: result[:gender],
        arv_number: result[:arv_number],
        birthdate: result[:birthdate],
        age_group: result[:age_group],
        result: measure[:value],
        result_modifier: measure[:modifier]
      }
    end
   end

   return processed_vl_results
  end

  def last_vl_result(patient_id)
    result_plus_date = ARTService::PatientVisit.new(Patient.find(patient_id),
       @end_date.to_date).viral_load_result

    return ['N/A', 'N/A'] if result_plus_date == 'N/A'
    value = result_plus_date.split("(")[0]
    value_date = result_plus_date.split("(")[1].gsub(")",'')
    return [value, Date.parse(value_date)]
  end

  def use_filing_number(patient_id, arv_number)
    return arv_number unless @use_filing_number

    identifier_types = PatientIdentifierType.where("name LIKE '%Filing number%'").map(&:patient_identifier_type_id)
    filing_numbers = PatientIdentifier.where("patient_id = ? AND identifier_type IN(?)",
      patient_id, identifier_types)
    return filing_numbers.blank? ? '' : filing_numbers.last.identifier
  end

end