# frozen_string_literal: true

module HTSService
  class DataCleaning
    include ModelUtils

    ITS_ENCOUNTERS = [
      'PREGNANCY STATUS', 'ITEMS GIVEN', 'CIRCUMCISION',
      'TESTING', 'RECENCY', 'DBS ORDER', 'APPOINTMENT',
      'HTS Contact', 'REFERRAL', 'REGISTRATION',
      'Partner Reception', 'ART Enrollment'
    ].freeze

    TOOLS = {
      'INCOMPLETE VISITS' => 'incomplete_visits',
      'MISSING LINKAGE' => 'missing_linkage',
      'DUPLICATE ENCOUNTERS' => 'duplicate_encounter',
      'PARTNER STATUS' => 'partner_status',
      'TEST DATE EARLIER THAN BIRTHDATE' => 'test_date_earlier_than_birthdate',
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
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.patient_id,
          e.encounter_type,
          i.identifier,
          DATE(e.encounter_datetime) as visit_date,
          pe.gender,
          pe.birthdate,
          pn.given_name,
          pn.family_name
        FROM patient p
        INNER JOIN person_name pn ON pn.person_id = p.patient_id 
          AND pn.voided = 0
        INNER JOIN person pe ON pe.person_id = p.patient_id 
          AND pe.voided = 0
        INNER JOIN encounter e ON e.patient_id = p.patient_id 
          AND e.voided = 0
        INNER JOIN patient_identifier i ON i.patient_id = p.patient_id AND i.identifier_type = #{patient_identifier_type('National id').id}
        LEFT JOIN obs vt ON vt.encounter_id = e.encounter_id
          AND vt.voided = 0
          AND vt.concept_id = #{concept('Visit type').id}
        LEFT JOIN encounter et ON et.patient_id = e.patient_id 
          AND et.voided = 0
          AND et.encounter_type = #{encounter_type('TESTING').id}
        WHERE e.program_id = #{program('HTC PROGRAM').id}
          AND vt.value_coded NOT IN (#{concept('Self test distribution').concept_id})
          AND DATE(e.encounter_datetime) >= DATE('#{@start_date}')
          AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
          AND et.encounter_id IS NULL
        GROUP BY p.patient_id
      SQL
    end

    # Patients tested positive but not linked to care
    def missing_linkage
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.patient_id,
          e.encounter_type,
          i.identifier,
          DATE(e.encounter_datetime) as visit_date,
          pe.gender,
          pe.birthdate,
          pn.given_name,
          pn.family_name
        FROM patient p
        INNER JOIN person_name pn ON pn.person_id = p.patient_id 
          AND pn.voided = 0
        INNER JOIN person pe ON pe.person_id = p.patient_id 
          AND pe.voided = 0
        INNER JOIN encounter e ON e.patient_id = p.patient_id 
          AND e.voided = 0
        INNER JOIN patient_identifier i ON i.patient_id = p.patient_id AND i.identifier_type = #{patient_identifier_type('National id').id}
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type 
          AND et.retired = 0
          AND e.encounter_type = #{encounter_type('TESTING').id}
        INNER JOIN obs hiv_status ON hiv_status.encounter_id = e.encounter_id
          AND hiv_status.voided = 0
          AND hiv_status.concept_id = #{concept('HIV STATUS').id}
          AND hiv_status.value_coded = #{concept('Positive').id}
        LEFT JOIN obs linkage ON linkage.encounter_id = e.encounter_id
          AND linkage.voided = 0
          AND linkage.concept_id = #{concept('HTC Serial number').id}
          AND linkage.value_text IS NULL
        WHERE e.program_id = #{program('HTC PROGRAM').id}
          AND e.voided = 0
          AND DATE(e.encounter_datetime) >= DATE('#{@start_date}')
          AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
      SQL
    end

    def duplicate_encounter
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          e.patient_id,
          e.encounter_type,
          i.identifier,
          et.name,
          DATE(e.encounter_datetime) as visit_date,
          pn.gender,
          pn.birthdate,
          p.given_name,
          p.family_name,
          COUNT(*) total
        FROM encounter e
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.retired = 0
        INNER JOIN patient_identifier i ON i.patient_id = e.patient_id AND i.identifier_type = #{patient_identifier_type('National id').id}
        INNER JOIN person_name p ON p.person_id = e.patient_id AND p.voided = 0
        INNER JOIN person pn ON pn.person_id = e.patient_id 
          AND pn.voided = 0
        WHERE e.program_id = #{program('HTC PROGRAM').id} AND e.voided = 0
        AND DATE(e.encounter_datetime) >= DATE('#{@start_date}') AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
        GROUP BY e.patient_id, e.encounter_type, DATE(e.encounter_datetime)
        HAVING total > 1
      SQL
    end

    # check if clients below 14 years old have a partner reception encounter
    def partner_status
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.patient_id,
          e.encounter_type,
          i.identifier,
          DATE(e.encounter_datetime) as visit_date,
          pe.gender,
          pn.given_name,
          pn.family_name,
          pe.birthdate
        FROM patient p
        INNER JOIN person_name pn ON pn.person_id = p.patient_id 
          AND pn.voided = 0
        INNER JOIN person pe ON pe.person_id = p.patient_id
          AND pe.voided = 0
        INNER JOIN encounter e ON e.patient_id = p.patient_id 
          AND e.voided = 0
          AND e.encounter_type = #{encounter_type('TESTING').id}
        INNER JOIN patient_identifier i ON i.patient_id = p.patient_id AND i.identifier_type = #{patient_identifier_type('National id').id}
        LEFT JOIN obs partner_status ON partner_status.person_id = p.patient_id
          AND partner_status.voided = 0
          AND partner_status.concept_id = #{concept('Partner HIV Status').id}
          AND partner_status.value_coded != #{concept('No Partner').id}
        WHERE e.program_id = #{program('HTC PROGRAM').id}
          AND e.voided = 0
          AND DATE(e.encounter_datetime) >= DATE('#{@start_date}')
          AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
          AND DATE(pe.birthdate) >= DATE(date_sub(e.encounter_datetime, interval 14 year)) 
      SQL
    end

    def test_date_earlier_than_birthdate
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          e.patient_id,
          e.encounter_type,
          i.identifier,
          DATE(e.encounter_datetime) as visit_date,
          pe.gender,
          pn.given_name,
          pn.family_name,
          pe.birthdate
        FROM patient p
        INNER JOIN person_name pn ON pn.person_id = p.patient_id
          AND pn.voided = 0
        INNER JOIN person pe ON pe.person_id = p.patient_id
          AND pe.voided = 0
        INNER JOIN encounter e ON e.patient_id = p.patient_id
          AND e.voided = 0
        INNER JOIN patient_identifier i ON i.patient_id = p.patient_id AND i.identifier_type = #{patient_identifier_type('National id').id}
        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
          AND et.retired = 0
          AND e.encounter_type = #{encounter_type('TESTING').id}
        WHERE e.program_id = #{program('HTC PROGRAM').id}
          AND e.voided = 0
          AND DATE(e.encounter_datetime) >= DATE('#{@start_date}')
          AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
          AND pe.birthdate > DATE(e.encounter_datetime)
      SQL
    end
  end
end
