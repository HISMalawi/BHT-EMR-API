class AddMultiColumnIndexToObs < ActiveRecord::Migration[5.2]
  def up
    puts('Creating index: idx_person_encounters')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_person_encounters ON encounter (patient_id, encounter_type)
    SQL

    puts('Creating index: idx_person_encounters_by_date')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_person_encounters_by_date ON encounter (encounter_datetime, patient_id, encounter_type)
    SQL

    puts('Creating index: idx_person_obs_answers_by_date...')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_person_obs_answers_by_date ON obs (obs_datetime, person_id, concept_id, value_coded)
    SQL

    puts('Creating index: idx_person_obs_answer...')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_person_obs_answer ON obs (person_id, concept_id, value_coded);
    SQL

    puts('Creating index: idx_obs_grouping')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_obs_grouping ON obs (person_id, obs_group_id, value_coded);
    SQL

    puts('Creating index: idx_order')
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_order ON orders (start_date, patient_id, concept_id, order_type_id)
    SQL
  end

  def down
    puts('Dropping index: idx_person_encounters')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_person_encounters ON encounter
    SQL

    puts('Dropping index: idx_person_encounters_by_date')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_person_encounters_by_date ON encounter
    SQL

    puts('Dropping index: idx_person_obs_answers_by_date...')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_person_obs_answers_by_date ON obs
    SQL

    puts('Dropping index: idx_person_obs_answer...')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_person_obs_answer ON obs
    SQL

    puts('Dropping index: idx_groupings...')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_obs_grouping ON obs
    SQL

    puts('Dropping index: idx_order')
    ActiveRecord::Base.connection.execute <<~SQL
      DROP INDEX idx_order ON orders
    SQL
  end
end
