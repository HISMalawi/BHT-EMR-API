# frozen_string_literal: true

module ANCService
  class DataCleaning
    FIRST_VISIT_ENC = ['VITALS', 'APPOINTMENT', 'ART_FOLLOWUP',
                       'TREATMENT', 'MEDICAL HISTORY', 'LAB RESULTS', 'UPDATE OUTCOME',
                       'DISPENSING', 'ANC EXAMINATION', 'CURRENT PREGNANCY',
                       'OBSTETRIC HISTORY', 'SURGICAL HISTORY', 'SOCIAL HISTORY',
                       'ANC VISIT TYPE'].freeze

    SUBSEQ_VISIT_ENC = ['VITALS', 'APPOINTMENT', 'ART_FOLLOWUP', 'TREATMENT',
                        'LAB RESULTS', 'UPDATE OUTCOME', 'DISPENSING', 'ANC VISIT TYPE'].freeze

    TOOLS = {
      'INCOMPLETE VISITS' => 'incomplete_visits',
      'DUPLICATE ENCOUNTERS' => 'duplicate_encounter'
    }.freeze

    def initialize(start_date, end_date, tool_name)
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @tool_name = tool_name.upcase
    end

    def results
      eval(TOOLS[@tool_name.to_s])
    rescue StandardError => e
      "#{e.class}: #{e.message}"
    end

    private

    def incomplete_visits
      @incomplete_visits = []
      query = "SELECT DATE(encounter_datetime) visit_date,
        GROUP_CONCAT(DISTINCT(e.encounter_type)) AS et,
        e.patient_id,
		(SELECT COUNT(DISTINCT(DATE(encounter_datetime))) FROM encounter
			WHERE patient_id = e.patient_id
        AND voided = 0
        AND DATE(encounter_datetime) <= DATE(e.encounter_datetime)
        AND program_id = 12
			) visit_no
        FROM encounter e WHERE Date(e.encounter_datetime) >= '#{@start_date}'
        AND Date(e.encounter_datetime) <= '#{@end_date}'
        AND voided = 0 AND program_id = 12
        GROUP BY e.patient_id, visit_date"
      visits = ActiveRecord::Base.connection.select_all(query)
      visits.each do |v|
        all_et = FIRST_VISIT_ENC
        patient_et = v['et'].split(',')
        patient_et = patient_et.map { |n| eval n }
        a = all_et.to_set.subset?(patient_et.to_set)
        next unless !a == true

        patient_name = Person.find(v['patient_id']).name
        national_id = PatientIdentifier.find_by_patient_id(v['patient_id']).identifier
        visit_hash = { 'name' => patient_name,
                       'n_id' => national_id,
                       'visit_no' => v['visit_no'],
                       'visit_date' => v['visit_date'].to_date.strftime('%d/%m/%Y'),
                       'patient_id' => v['patient_id'] }

        @incomplete_visits << visit_hash
      end
      @incomplete_visits
    end

    def duplicate_encounter
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          e.patient_id,
          e.encounter_type,
          i.identifier,
          et.name,
          DATE(e.encounter_datetime) as visit_date,
          p.given_name,
          p.family_name,
          COUNT(*) total
        FROM encounter e
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.retired = 0
        INNER JOIN patient_identifier i ON i.patient_id = e.patient_id AND i.identifier_type = #{PatientIdentifierType.find_by(name: 'National id').id}
        INNER JOIN person_name p ON p.person_id = e.patient_id AND p.voided = 0
        WHERE e.program_id = #{Program.find_by_name('ANC PROGRAM').id} AND e.voided = 0
        AND DATE(e.encounter_datetime) >= DATE('#{@start_date}') AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
        GROUP BY e.patient_id, e.encounter_type, DATE(e.encounter_datetime)
        HAVING IF (e.encounter_type = #{EncounterType.find_by(name: 'VITALS').id}, total > 2, total > 1)
      SQL
    end

    # encounters after patient died
    def encounters_after_death
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          e.patient_id,
          pid.identifier,
          pn.given_name,
          pn.family_name,
          pd.start_date AS patient_died_date,
          MIN(e.encounter_datetime) AS minimum_encounter_datetime,
          COUNT(*) total_encounters
        FROM encounter e
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.retired = 0
        LEFT JOIN patient_identifier pid ON pid.patient_id = e.patient_id AND pid.identifier_type = #{PatientIdentifierType.find_by(name: 'National id').id} AND pid.voided = 0
        LEFT JOIN person_name pn ON pn.person_id = e.patient_id AND pn.voided = 0
        INNER JOIN (
          SELECT ps.start_date, pp.program_id, pp.patient_id
          FROM patient_state ps
          INNER JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id AND pp.voided = 0
          WHERE ps.voided = 0 AND pp.program_id = #{Program.find_by_name('ANC PROGRAM').id} AND ps.state IN (
            SELECT s.program_workflow_state_id
            FROM program p
            INNER JOIN program_workflow w ON w.program_id = p.program_id
            INNER JOIN program_workflow_state s ON s.program_workflow_id = w.program_workflow_id
            INNER JOIN concept_name n ON n.concept_id = s.concept_id
            WHERE s.initial = 0 AND terminal = 1 AND p.program_id = #{Program.find_by_name('ANC PROGRAM').id} s.retired = 0 AND n.name = 'Patient died'
            GROUP BY n.concept_id
          )
        ) as pd ON pd.program_id = e.program_id AND pd.patient_id = e.patient_id AND DATE(e.encounter_datetime) > pd.start_date
        WHERE e.voided = 0
        GROUP BY e.patient_id;
      SQL
    end
  end
end
