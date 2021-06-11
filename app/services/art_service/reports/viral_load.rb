
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
    # global_property = GlobalProperty.find_by(property: 'use.filing.number')
    @use_filing_number = false # global_property&.property_value&.downcase == 'true'

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

  def start_date
    ActiveRecord::Base.connection.quote(@start_date)
  end

  def end_date
    ActiveRecord::Base.connection.quote(@end_date)
  end

  def patient_identifier_type_id
    identifier_type_name = @use_filing_number ? 'Filing Number' : 'ARV Number'
    identifier_type = PatientIdentifierType.find_by_name!(identifier_type_name)

    ActiveRecord::Base.connection.quote(identifier_type.id)
  end

  def program_id
    ActiveRecord::Base.connection.quote(@program.program_id)
  end

  def closing_states
    state_concepts = ConceptName.where(name: ['Patient died', 'Patient transferred out', 'Treatment stopped'])
                                .select(:concept_id)
    states = ProgramWorkflowState.where(concept_id: state_concepts)
                                 .joins(:program_workflow)
                                 .merge(ProgramWorkflow.where(program: @program))

    PatientState.joins(:program_workflow_state)
                .merge(states)
                .select(:state)
                .distinct(:state)
                .to_sql
  end

  def potential_get_clients
    observations = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT obs.person_id,
             obs.value_datetime,
             date_antiretrovirals_started(obs.person_id, NULL) AS start_date,
             patient_identifier.identifier,
             person_name.given_name,
             person_name.family_name,
             person.birthdate,
             person.gender
      FROM obs
      INNER JOIN encounter
        ON encounter.encounter_id = obs.encounter_id
        AND encounter.program_id = #{program_id}
        AND encounter_type = (
          SELECT encounter_type_id
          FROM encounter_type
          WHERE encounter_type.name = 'Appointment'
            AND encounter_type.retired = 0
          LIMIT 1
        )
        AND encounter.voided = 0
      LEFT JOIN person
        ON person.person_id = obs.person_id
        AND person.voided = 0
      LEFT JOIN person_name
        ON person_name.person_id = obs.person_id
        AND person_name.voided = 0
      LEFT JOIN patient_identifier
        ON patient_identifier.patient_id = obs.person_id
        AND patient_identifier.identifier_type = #{patient_identifier_type_id}
        AND patient_identifier.voided = 0
      INNER JOIN patient_program
        ON patient_program.program_id = encounter.program_id
        AND patient_program.patient_id = encounter.patient_id
        AND patient_program.voided = 0
      INNER JOIN patient_state
        ON patient_state.patient_program_id = patient_program.patient_program_id
        AND patient_state.voided = 0
        AND patient_state.state NOT IN (#{closing_states})
      /* Limit states above to most recent states for each patient */
      INNER JOIN (
        SELECT patient_state.patient_program_id,
               MAX(patient_state.start_date) AS start_date
        FROM patient_state
        INNER JOIN patient_program
          ON patient_program.program_id = #{program_id}
          AND patient_program.voided = 0
          AND patient_program.patient_program_id = patient_state.patient_program_id
        WHERE patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
          AND patient_state.voided = 0
        GROUP BY patient_state.patient_program_id
      ) AS patient_recent_state_dates
        ON patient_recent_state_dates.patient_program_id = patient_state.patient_program_id
        AND patient_recent_state_dates.start_date = patient_state.start_date
      WHERE obs.concept_id = (
          SELECT concept_id
          FROM concept_name
          WHERE concept_name.name = 'Appointment date'
            AND concept_name.voided = 0
          LIMIT 1
        )
        AND obs.value_datetime >= DATE(#{start_date})
        AND obs.value_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
        AND obs.voided = 0
      GROUP BY obs.person_id
      ORDER BY obs.value_datetime
    SQL

    observations.map do |ob|
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