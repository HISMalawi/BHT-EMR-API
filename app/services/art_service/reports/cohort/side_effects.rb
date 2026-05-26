# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      module SideEffects
        def self.update_side_effects(date)
          load_patients_with_known_side_effects(date)
          load_patients_missing_side_effects(date)
        end

        # Classifies each 'On antiretrovirals' patient as Yes/No in a single pass
        # by computing the last visit once and using MAX(CASE...) to detect any
        # Yes-coded child obs at that visit.
        # Patients with no side-effects obs at all fall through to load_patients_missing_side_effects.
        def self.load_patients_with_known_side_effects(date)
          date = ActiveRecord::Base.connection.quote(date)

          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_side_effects (patient_id, has_se)
            SELECT
              patients.patient_id,
              IF(
                MAX(CASE WHEN side_effects.value_coded = #{yes.concept_id} THEN 1 ELSE 0 END) = 1,
                'Yes',
                'No'
              ) AS has_se
            FROM temp_earliest_start_date AS patients
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = patients.patient_id
              AND temp_patient_outcomes.moh_cum_outcome = 'On antiretrovirals'
            /* Compute last side-effects visit once for all patients */
            INNER JOIN (
              SELECT person_id, MAX(obs_datetime) AS obs_datetime
              FROM obs
              WHERE concept_id = #{art_side_effects.concept_id}
                AND obs_datetime < (DATE(#{date}) + INTERVAL 1 DAY)
                AND voided = 0
              GROUP BY person_id
            ) AS last_visit
              ON last_visit.person_id = patients.patient_id
              AND last_visit.obs_datetime >= (patients.date_enrolled + INTERVAL 1 DAY)
            INNER JOIN obs AS side_effects_group
              ON side_effects_group.person_id = patients.patient_id
              AND side_effects_group.concept_id = #{art_side_effects.concept_id}
              AND side_effects_group.obs_datetime = last_visit.obs_datetime
              AND side_effects_group.voided = 0
            INNER JOIN obs AS side_effects
              ON side_effects.person_id = patients.patient_id
              AND side_effects.obs_group_id = side_effects_group.obs_id
              AND side_effects.voided = 0
            WHERE patients.date_enrolled <= #{date}
            GROUP BY patients.patient_id
          SQL
        end

        def self.load_patients_missing_side_effects(date)
          date = ActiveRecord::Base.connection.quote(date)

          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_side_effects
            SELECT patient_id, 'Unknown' FROM temp_earliest_start_date
            WHERE date_enrolled <= #{date}
              AND patient_id NOT IN (SELECT patient_id FROM temp_patient_side_effects)
          SQL
        end

        def self.yes
          @yes ||= Concept.find_by_name('Yes')
        end

        def self.art_side_effects
          @art_side_effects ||= Concept.find_by_name('Malawi ART Side Effects')
        end
      end
    end
  end
end
