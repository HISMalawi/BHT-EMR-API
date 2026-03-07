# frozen_string_literal: true

module AncService
  class DashboardStatsQueries
    include ModelUtils

    LOGGER = Rails.logger
    ANC_ENROLLMENT_ENCOUNTER_TYPE_ID = 237.freeze
    LAB_ENCOUNTER_TYPE_ID = 13
    QUICK_CHECK_CONCEPT_ID = 206
    MIN_ANC_CONTACTS_FOR_4_PLUS = 4

    def new_and_continuing_anc_clients
      return 0 if anc_program_id.nil?
      count, source = if anc_enrollment_encounter_type_id.present?
        [count_by_anc_enrollment_encounter, 'encounter']
      else
        [count_by_patient_program, 'patient_program']
      end
      LOGGER.info "[ANC DashboardStatsQueries] new_and_continuing_anc_clients count=#{count} source=#{source}"
      count
    end

    def women_with_ultrasound_scanning
      return 0 if anc_program_id.nil?
      count = count_women_with_ga_by_ultrasound
      LOGGER.info "[ANC DashboardStatsQueries] women_with_ultrasound_scanning count=#{count}"
      count
    end

    def proportion_women_ultrasound_scanning
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (women_with_ultrasound_scanning.to_f / total).round(4)
    end

    def women_with_4_plus_anc_contacts
      return 0 if anc_program_id.nil?
      count = count_women_with_4_plus_anc_contacts
      LOGGER.info "[ANC DashboardStatsQueries] women_with_4_plus_anc_contacts count=#{count}"
      count
    end

    def percentage_women_4_plus_anc_contacts
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (women_with_4_plus_anc_contacts.to_f / total * 100).round(2)
    end

    def clients_with_previous_uterine_scars
      return 0 if anc_program_id.nil?
      count = count_clients_with_previous_uterine_scars
      LOGGER.info "[ANC DashboardStatsQueries] clients_with_previous_uterine_scars count=#{count}"
      count
    end

    def percentage_clients_previous_uterine_scars
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (clients_with_previous_uterine_scars.to_f / total * 100).round(2)
    end

    def anc_hiv_positive_clients
      return 0 if anc_program_id.nil?
      count = count_anc_clients_with_lab_result('HIV Test', positive_only: true)
      LOGGER.info "[ANC DashboardStatsQueries] anc_hiv_positive_clients count=#{count}"
      count
    end

    def anc_hiv_positive_on_art
      return 0 if anc_program_id.nil?
      count = count_anc_hiv_positive_and_on_art
      LOGGER.info "[ANC DashboardStatsQueries] anc_hiv_positive_on_art count=#{count}"
      count
    end

    def percentage_anc_hiv_positive_on_art
      total = anc_hiv_positive_clients
      return 0.0 if total.zero?
      (anc_hiv_positive_on_art.to_f / total * 100).round(2)
    end

    def women_tested_syphilis_during_anc
      return 0 if anc_program_id.nil?
      count = count_anc_clients_with_lab_result('Syphilis Test Result')
      LOGGER.info "[ANC DashboardStatsQueries] women_tested_syphilis_during_anc count=#{count}"
      count
    end

    def percentage_women_tested_syphilis_during_anc
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (women_tested_syphilis_during_anc.to_f / total * 100).round(2)
    end

    def women_tested_hepatitis_b_during_anc
      return 0 if anc_program_id.nil?
      count = count_anc_clients_with_lab_result('Hepatitis B')
      LOGGER.info "[ANC DashboardStatsQueries] women_tested_hepatitis_b_during_anc count=#{count}"
      count
    end

    def percentage_women_tested_hepatitis_b_during_anc
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (women_tested_hepatitis_b_during_anc.to_f / total * 100).round(2)
    end

    private

    def anc_program_id
      @anc_program_id ||= Program.find_by(name: 'ANC PROGRAM')&.id
    end

    def anc_enrollment_encounter_type_id
      @anc_enrollment_encounter_type_id ||= ANC_ENROLLMENT_ENCOUNTER_TYPE_ID
    end

    def count_by_anc_enrollment_encounter
      Encounter.where(
        program_id: anc_program_id,
        encounter_type: anc_enrollment_encounter_type_id,
        voided: 0
      ).distinct
       .count(:patient_id)
    end

    def count_by_patient_program
      PatientProgram.where(
        program_id: anc_program_id,
        voided: 0
      ).count(:patient_id)
    end

    def count_women_with_ga_by_ultrasound
      gestation_concept_id = ConceptName.find_by(name: 'Gestation age to be used')&.concept_id
      ga_ultrasound_concept_id = ConceptName.find_by(name: 'GA by ultrasound')&.concept_id
      
      return 0 if gestation_concept_id.nil?
      scope = Observation.joins(:encounter)
                         .where(encounter: { program_id: anc_program_id, voided: 0 })
                         .where(voided: 0, concept_id: gestation_concept_id)

      if ga_ultrasound_concept_id.present?
        scope = scope.where(
          'obs.value_text = ? OR obs.value_coded = ?',
          'GA by ultrasound',
          ga_ultrasound_concept_id
        )
      else
        scope = scope.where('obs.value_text = ?', 'GA by ultrasound')
      end

      scope.distinct.count(:person_id)
    end

    def count_women_with_4_plus_anc_contacts
      sql = <<~SQL.squish
        SELECT COUNT(*) AS cnt FROM (
          SELECT obs.person_id
          FROM obs
          INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id
            AND encounter.program_id = ?
            AND encounter.voided = 0
          WHERE obs.voided = 0 AND obs.concept_id = ?
          GROUP BY obs.person_id
          HAVING MAX(COALESCE(obs.value_numeric, CAST(NULLIF(TRIM(obs.value_text), '') AS UNSIGNED), 0)) >= ?
        ) t
      SQL
      result = Observation.connection.select_one(
        ActiveRecord::Base.send(:sanitize_sql_array, [
          sql,
          anc_program_id,
          QUICK_CHECK_CONCEPT_ID,
          MIN_ANC_CONTACTS_FOR_4_PLUS
        ])
      )
      result ? result['cnt'].to_i : 0
    end

    def count_clients_with_previous_uterine_scars
      scars_concept_id = ConceptName.find_by(name: 'Scar')&.concept_id
      return 0 if scars_concept_id.nil?

      Observation.joins(:encounter)
                 .where(encounter: { program_id: anc_program_id, voided: 0 })
                 .where(voided: 0, concept_id: scars_concept_id)
                 .where('obs.value_text = ?', 'Present')
                 .distinct
                 .count(:person_id)
    end

    def hiv_status_concept_id
      @hiv_status_concept_id ||= ConceptName.find_by(name: 'HIV Test')&.concept_id
    end

    def positive_concept_id
      @positive_concept_id ||= ConceptName.find_by(name: 'Positive')&.concept_id
    end

    def count_anc_clients_with_obs_concept_value(concept_id, value_coded_id, value_text_fallback)
      return 0 if concept_id.nil?
      scope = Observation.joins(:encounter)
                         .where(encounter: { program_id: anc_program_id, voided: 0 })
                         .where(voided: 0, concept_id: concept_id)
      if value_coded_id.present?
        scope = scope.where('obs.value_text = ? OR obs.value_coded = ?', value_text_fallback, value_coded_id)
      else
        scope = scope.where('obs.value_text = ?', value_text_fallback)
      end
      scope.distinct.count(:person_id)
    end

    def count_anc_hiv_positive_and_on_art
      return 0 if hiv_test_concept_id.nil? || positive_concept_id.nil?
      hiv_positive_ids = lab_obs_scope
                        .where(concept_id: hiv_test_concept_id)
                        .where('obs.value_text = ? OR obs.value_coded = ?', 'Positive', positive_concept_id)
                        .distinct
                        .pluck(:person_id)
      return 0 if hiv_positive_ids.blank?
      Observation.joins(:encounter)
                 .where(encounter: { program_id: anc_program_id, voided: 0 })
                 .where(voided: 0, concept_id: on_art_concept_id)
                 .where('obs.value_text = ? OR obs.value_coded = ?', 'Yes', yes_concept_id)
                 .where(person_id: hiv_positive_ids)
                 .distinct
                 .count(:person_id)
    end

    def hiv_test_concept_id
      @hiv_test_concept_id ||= ConceptName.find_by(name: 'HIV Test')&.concept_id
    end

    def lab_obs_scope
      Observation.joins(:encounter).where(
        encounter: {
          program_id: anc_program_id,
          encounter_type: LAB_ENCOUNTER_TYPE_ID,
          voided: 0
        }
      ).where(voided: 0)
    end

    def count_anc_clients_with_lab_result(concept_name, positive_only: false)
      concept_id = ConceptName.find_by(name: concept_name)&.concept_id
      return 0 if concept_id.nil?
      scope = lab_obs_scope.where(concept_id: concept_id)
      if positive_only
        return 0 if positive_concept_id.nil?
        scope = scope.where('obs.value_text = ? OR obs.value_coded = ?', 'Positive', positive_concept_id)
      else
        scope = scope.where('obs.value_text IS NOT NULL OR obs.value_coded IS NOT NULL')
      end
      scope.distinct.count(:person_id)
    end
  end
end
