# frozen_string_literal: true

module MnhService
  class AncStatsQueries
    include ModelUtils

    LOGGER = Rails.logger
    ANC_ENROLLMENT_ENCOUNTER_TYPE_ID = 237
    LAB_ENCOUNTER_TYPE_ID = 13
    QUICK_CHECK_CONCEPT_ID = 206
    MIN_ANC_CONTACTS_FOR_4_PLUS = 4

    def initialize(program_id = nil)
      @program_id = program_id
    end

    def stats_hash(_date = nil)
      {
        new_and_continuing_anc_clients: new_and_continuing_anc_clients,
        women_with_ultrasound_scanning: women_with_ultrasound_scanning,
        proportion_women_ultrasound_scanning: proportion_women_ultrasound_scanning,
        women_with_4_plus_anc_contacts: women_with_4_plus_anc_contacts,
        percentage_women_4_plus_anc_contacts: percentage_women_4_plus_anc_contacts,
        clients_with_previous_uterine_scars: clients_with_previous_uterine_scars,
        percentage_clients_previous_uterine_scars: percentage_clients_previous_uterine_scars,
        anc_hiv_positive_clients: anc_hiv_positive_clients,
        anc_hiv_positive_on_art: anc_hiv_positive_on_art,
        percentage_anc_hiv_positive_on_art: percentage_anc_hiv_positive_on_art,
        women_tested_syphilis_during_anc: women_tested_syphilis_during_anc,
        percentage_women_tested_syphilis_during_anc: percentage_women_tested_syphilis_during_anc,
        women_tested_hepatitis_b_during_anc: women_tested_hepatitis_b_during_anc,
        percentage_women_tested_hepatitis_b_during_anc: percentage_women_tested_hepatitis_b_during_anc
      }
    end

    def new_and_continuing_anc_clients
      return 0 if anc_program_id.nil?
      @new_and_continuing_anc_clients ||= (
        anc_enrollment_encounter_type_id.present? ? count_by_anc_enrollment_encounter : count_by_patient_program
      )
    end

    def women_with_ultrasound_scanning
      return 0 if anc_program_id.nil?
      @women_with_ultrasound_scanning ||= count_women_with_ga_by_ultrasound
    end

    def proportion_women_ultrasound_scanning
      percentage_ratio(women_with_ultrasound_scanning, new_and_continuing_anc_clients, 4)
    end

    def women_with_4_plus_anc_contacts
      return 0 if anc_program_id.nil?
      @women_with_4_plus_anc_contacts ||= count_women_with_4_plus_anc_contacts
    end

    def percentage_women_4_plus_anc_contacts
      percentage_of(women_with_4_plus_anc_contacts, new_and_continuing_anc_clients)
    end

    def clients_with_previous_uterine_scars
      return 0 if anc_program_id.nil?
      @clients_with_previous_uterine_scars ||= count_clients_with_previous_uterine_scars
    end

    def percentage_clients_previous_uterine_scars
      percentage_of(clients_with_previous_uterine_scars, new_and_continuing_anc_clients)
    end

    def anc_hiv_positive_clients
      return 0 if anc_program_id.nil?
      @anc_hiv_positive_clients ||= count_anc_clients_with_lab_result('HIV Test', positive_only: true)
    end

    def anc_hiv_positive_on_art
      return 0 if anc_program_id.nil?
      @anc_hiv_positive_on_art ||= count_anc_hiv_positive_and_on_art
    end

    def percentage_anc_hiv_positive_on_art
      percentage_of(anc_hiv_positive_on_art, anc_hiv_positive_clients)
    end

    def women_tested_syphilis_during_anc
      return 0 if anc_program_id.nil?
      @women_tested_syphilis_during_anc ||= count_anc_clients_with_lab_result('Syphilis Test Result')
    end

    def percentage_women_tested_syphilis_during_anc
      percentage_of(women_tested_syphilis_during_anc, new_and_continuing_anc_clients)
    end

    def women_tested_hepatitis_b_during_anc
      return 0 if anc_program_id.nil?
      @women_tested_hepatitis_b_during_anc ||= count_anc_clients_with_lab_result('Hepatitis B')
    end

    def percentage_women_tested_hepatitis_b_during_anc
      percentage_of(women_tested_hepatitis_b_during_anc, new_and_continuing_anc_clients)
    end

    private

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
    end

    def percentage_ratio(count, total, decimals = 4)
      total.to_i.zero? ? 0.0 : (count.to_f / total).round(decimals)
    end

    def anc_program_id
      @anc_program_id ||= @program_id.presence || Program.find_by(name: 'ANC PROGRAM')&.id
    end

    def anc_enrollment_encounter_type_id
      @anc_enrollment_encounter_type_id ||= ANC_ENROLLMENT_ENCOUNTER_TYPE_ID
    end

    def concept_id_for(name)
      @concept_ids_by_name ||= {}
      @concept_ids_by_name[name] ||= ConceptName.find_by(name: name)&.concept_id
    end

    def positive_concept_id
      @positive_concept_id ||= concept_id_for('Positive')
    end

    def hiv_test_concept_id
      @hiv_test_concept_id ||= concept_id_for('HIV Test')
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

    def anc_encounter_scope
      Observation.joins(:encounter).where(
        encounter: { program_id: anc_program_id, voided: 0 }
      ).where(voided: 0)
    end

    def count_by_anc_enrollment_encounter
      Encounter.where(
        program_id: anc_program_id,
        encounter_type: anc_enrollment_encounter_type_id,
        voided: 0
      ).distinct.count(:patient_id)
    end

    def count_by_patient_program
      PatientProgram.where(program_id: anc_program_id, voided: 0).count(:patient_id)
    end

    def count_women_with_ga_by_ultrasound
      gestation_id = concept_id_for('Gestation age to be used')
      ga_ultrasound_id = concept_id_for('GA by ultrasound')
      return 0 if gestation_id.nil?

      scope = anc_encounter_scope.where(concept_id: gestation_id)
      if ga_ultrasound_id.present?
        scope = scope.where('obs.value_text = ? OR obs.value_coded = ?', 'GA by ultrasound', ga_ultrasound_id)
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
            AND encounter.program_id = ? AND encounter.voided = 0
          WHERE obs.voided = 0 AND obs.concept_id = ?
          GROUP BY obs.person_id
          HAVING MAX(COALESCE(obs.value_numeric, CAST(NULLIF(TRIM(obs.value_text), '') AS UNSIGNED), 0)) >= ?
        ) t
      SQL
      result = Observation.connection.select_one(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, anc_program_id, QUICK_CHECK_CONCEPT_ID, MIN_ANC_CONTACTS_FOR_4_PLUS])
      )
      result ? result['cnt'].to_i : 0
    end

    def count_clients_with_previous_uterine_scars
      scars_id = concept_id_for('Scar')
      return 0 if scars_id.nil?

      anc_encounter_scope
        .where(concept_id: scars_id)
        .where('obs.value_text = ?', 'Present')
        .distinct
        .count(:person_id)
    end

    def count_anc_hiv_positive_and_on_art
      return 0 if hiv_test_concept_id.nil? || positive_concept_id.nil?

      hiv_positive_ids = lab_obs_scope
        .where(concept_id: hiv_test_concept_id)
        .where('obs.value_text = ? OR obs.value_coded = ?', 'Positive', positive_concept_id)
        .distinct
        .pluck(:person_id)
      on_art_concept_id = concept_id_for('On ART')
      yes_concept_id = concept_id_for('Yes')
      return hiv_positive_ids.size if on_art_concept_id.nil? || yes_concept_id.nil? || hiv_positive_ids.empty?

      Observation.joins(:encounter).where(
        encounter: { program_id: anc_program_id, voided: 0 }
      ).where(voided: 0).where(person_id: hiv_positive_ids)
        .where(concept_id: on_art_concept_id)
        .where('obs.value_text = ? OR obs.value_coded = ?', 'Yes', yes_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_anc_clients_with_lab_result(concept_name, positive_only: false)
      concept_id = concept_id_for(concept_name)
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
