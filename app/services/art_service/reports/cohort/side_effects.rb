# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      module SideEffects
        def self.update_side_effects(date)
          # Pre-compute last_visit once (13-14s) so both with/without queries can reuse it
          # via PK lookup instead of each independently scanning 6M side-effects obs.
          load_last_side_effects_visit(date)
          begin
            load_patients_with_side_effects(date)
            load_patients_without_side_effects(date)
            load_patients_missing_side_effects(date)
          ensure
            ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_last_se_visit')
          end
        end

        def self.load_last_side_effects_visit(date)
          date = ActiveRecord::Base.connection.quote(date)
          conn = ActiveRecord::Base.connection
          conn.execute('DROP TABLE IF EXISTS temp_last_se_visit')
          conn.execute(<<~SQL)
            CREATE TABLE temp_last_se_visit (
              person_id INT NOT NULL,
              obs_datetime DATETIME NOT NULL,
              PRIMARY KEY (person_id)
            )
          SQL
          conn.execute(<<~SQL)
            INSERT INTO temp_last_se_visit
            SELECT person_id, MAX(obs_datetime) AS obs_datetime
            FROM obs
            WHERE concept_id = #{art_side_effects.concept_id}
              AND obs_datetime < (DATE(#{date}) + INTERVAL 1 DAY)
              AND voided = 0
              AND person_id IN (
                SELECT patient_id FROM temp_patient_outcomes WHERE moh_cum_outcome = 'On antiretrovirals'
              )
            GROUP BY person_id
          SQL
        end

        def self.load_patients_with_side_effects(date)
          date = ActiveRecord::Base.connection.quote(date)

          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_side_effects
            SELECT patients.patient_id,
                   'Yes'
            FROM temp_earliest_start_date AS patients
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = patients.patient_id
              AND temp_patient_outcomes.moh_cum_outcome = 'On antiretrovirals'
            INNER JOIN obs AS side_effects_group
              ON side_effects_group.person_id = patients.patient_id
              AND side_effects_group.concept_id = #{art_side_effects.concept_id}
              AND side_effects_group.voided = 0
            /* Use pre-computed last_visit table (PK lookup) instead of inline subquery */
            INNER JOIN temp_last_se_visit AS last_visit
              ON last_visit.person_id = side_effects_group.person_id
              AND last_visit.obs_datetime = side_effects_group.obs_datetime
              AND last_visit.obs_datetime >= (patients.date_enrolled + INTERVAL 1 DAY)
            INNER JOIN obs AS side_effects
              ON side_effects.person_id = patients.patient_id
              AND side_effects_group.obs_id = side_effects.obs_group_id
              AND side_effects.value_coded = #{yes.concept_id}
              AND side_effects.voided = 0
            WHERE patients.date_enrolled <= #{date}
            GROUP BY patients.patient_id
          SQL
        end

        def self.load_patients_without_side_effects(date)
          date = ActiveRecord::Base.connection.quote(date)

          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_side_effects
            SELECT patients.patient_id,
                   'No'
            FROM temp_earliest_start_date AS patients
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = patients.patient_id
              AND temp_patient_outcomes.moh_cum_outcome = 'On antiretrovirals'
            INNER JOIN obs AS side_effects_group
              ON side_effects_group.person_id = patients.patient_id
              AND side_effects_group.concept_id = #{art_side_effects.concept_id}
              AND side_effects_group.voided = 0
            /* Use pre-computed last_visit table (PK lookup) instead of inline subquery */
            INNER JOIN temp_last_se_visit AS last_visit
              ON last_visit.person_id = side_effects_group.person_id
              AND last_visit.obs_datetime = side_effects_group.obs_datetime
              AND last_visit.obs_datetime >= (patients.date_enrolled + INTERVAL 1 DAY)
            INNER JOIN obs AS side_effects
              ON side_effects.person_id = patients.patient_id
              AND side_effects_group.obs_id = side_effects.obs_group_id
              AND side_effects.value_coded = #{no.concept_id}
              AND side_effects.voided = 0
            WHERE patients.date_enrolled <= #{date}
              AND patients.patient_id NOT IN (
                SELECT patient_id FROM temp_patient_side_effects WHERE has_se = 'Yes'
              )
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

        def self.no
          @no ||= Concept.find_by_name('No')
        end

        def self.art_side_effects
          @art_side_effects ||= Concept.find_by_name('Malawi ART Side Effects')
        end
      end
    end
  end
end
