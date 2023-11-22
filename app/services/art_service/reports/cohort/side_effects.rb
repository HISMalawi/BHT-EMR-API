# frozen_string_literal: true

module ArtService::Reports::Cohort::SideEffects
  def self.update_side_effects(date)
    initialize_table

    load_patients_with_side_effects(date)
    load_patients_without_side_effects(date)
    load_patients_missing_side_effects(date)
  end

  def self.initialize_table
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_patient_side_effects
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_patient_side_effects (
        patient_id INT(11) PRIMARY KEY,
        has_se VARCHAR(120) NOT NULL
      )
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_side_effects ON temp_patient_side_effects (patient_id, has_se)
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
        AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
      INNER JOIN obs AS side_effects_group
        ON side_effects_group.person_id = patients.patient_id
        AND side_effects_group.concept_id = #{art_side_effects.concept_id}
        AND side_effects_group.voided = 0
      /* Limit check to last visit before #{date} */
      INNER JOIN (
        SELECT person_id, MAX(obs_datetime) AS obs_datetime FROM obs
        WHERE concept_id = #{art_side_effects.concept_id}
          /* Side effects on initial visit are treated as contra-indications */
          AND obs_datetime < (DATE(#{date}) + INTERVAL 1 DAY)
          AND voided = 0
          AND person_id IN (SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'On antiretrovirals')
        GROUP BY person_id
      ) AS last_visit
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
        AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
      INNER JOIN obs AS side_effects_group
        ON side_effects_group.person_id = patients.patient_id
        AND side_effects_group.concept_id = #{art_side_effects.concept_id}
        AND side_effects_group.voided = 0
      /* Limit check to last visit before #{date} */
      INNER JOIN (
        SELECT person_id, MAX(obs_datetime) AS obs_datetime FROM obs
        WHERE concept_id = #{art_side_effects.concept_id}
          /* Side effects on initial visit are treated as contra-indications */
          AND obs_datetime < (DATE(#{date}) + INTERVAL 1 DAY)
          AND voided = 0
          AND person_id IN (
            SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'On antiretrovirals'
          )
        GROUP BY person_id
      ) AS last_visit
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
