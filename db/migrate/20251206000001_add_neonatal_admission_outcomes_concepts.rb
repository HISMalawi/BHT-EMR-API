# frozen_string_literal: true

class AddNeonatalAdmissionOutcomesConcepts < ActiveRecord::Migration[7.0]
  def up
    # Create admission outcome concepts
    concepts = [
      # Main admission outcome concept (coded)
      { name: 'Admission outcome', datatype: 'Coded', class: 'Finding' },

      # Answer concepts for admission outcome
      { name: 'Admit to Ward', datatype: 'N/A', class: 'Misc' },
      { name: 'Referrer to main hospital', datatype: 'N/A', class: 'Misc' },
      { name: 'Died During Admission', datatype: 'N/A', class: 'Misc' },
      { name: 'Discharged home (Well Baby)', datatype: 'N/A', class: 'Misc' },
      { name: 'Other', datatype: 'N/A', class: 'Misc' },

      # Safeguarding concerns concept (text)
      { name: 'Safeguard concerns', datatype: 'Text', class: 'Finding' }
    ]

    concepts.each do |concept_data|
      create_or_update_concept(
        concept_data[:name],
        concept_data[:datatype],
        concept_data[:class]
      )
    end

    # Create answer set for Admission outcome
    # Note: 'Absconded' already exists from the Visit outcome concept
    create_answer_set(
      'Admission outcome',
      [
        'Admit to Ward',
        'Referrer to main hospital',
        'Died During Admission',
        'Absconded',
        'Discharged home (Well Baby)',
        'Other'
      ]
    )
  end

  def down
    concept_names = [
      'Admission outcome',
      'Admit to Ward',
      'Referrer to main hospital',
      'Died During Admission',
      'Discharged home (Well Baby)',
      'Safeguard concerns'
      # Note: Not removing 'Absconded' and 'Other' as they might be used elsewhere
    ]

    concept_names.each do |name|
      execute <<-SQL.squish
        UPDATE concept c
        INNER JOIN concept_name cn ON c.concept_id = cn.concept_id
        SET c.retired = 1
        WHERE cn.name = '#{ActiveRecord::Base.sanitize_sql_for_conditions(name)}'
      SQL
    end
  end

  private

  def create_or_update_concept(name, datatype_name, class_name)
    # Get or create concept datatype
    datatype_id = get_or_create_concept_datatype(datatype_name)

    # Get or create concept class
    class_id = get_or_create_concept_class(class_name)

    # Check if concept already exists
    existing_concept = ActiveRecord::Base.connection.select_value(
      "SELECT c.concept_id FROM concept c
       INNER JOIN concept_name cn ON c.concept_id = cn.concept_id
       WHERE cn.name = '#{ActiveRecord::Base.sanitize_sql_for_conditions(name)}'
       LIMIT 1"
    )

    if existing_concept
      # Update existing concept
      execute <<-SQL.squish
        UPDATE concept
        SET datatype_id = #{datatype_id},
            class_id = #{class_id},
            retired = 0
        WHERE concept_id = #{existing_concept}
      SQL
      return existing_concept
    end

    # Create new concept
    execute <<-SQL.squish
      INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
      VALUES (0, #{datatype_id}, #{class_id}, 0, 1, NOW(), UUID())
    SQL

    concept_id = ActiveRecord::Base.connection.select_value('SELECT LAST_INSERT_ID()')

    # Create concept name
    execute <<-SQL.squish
      INSERT INTO concept_name (
        concept_id, name, locale, creator, date_created,
        voided, uuid, concept_name_type, locale_preferred
      )
      VALUES (
        #{concept_id},
        '#{ActiveRecord::Base.sanitize_sql_for_conditions(name)}',
        'en', 1, NOW(), 0, UUID(), 'FULLY_SPECIFIED', 1
      )
    SQL

    concept_id
  end

  def get_or_create_concept_datatype(name)
    existing = ActiveRecord::Base.connection.select_value(
      "SELECT concept_datatype_id FROM concept_datatype WHERE name = '#{name}' LIMIT 1"
    )

    return existing if existing

    execute <<-SQL.squish
      INSERT INTO concept_datatype (name, description, creator, date_created, uuid)
      VALUES ('#{name}', '#{name}', 1, NOW(), UUID())
    SQL

    ActiveRecord::Base.connection.select_value('SELECT LAST_INSERT_ID()')
  end

  def get_or_create_concept_class(name)
    existing = ActiveRecord::Base.connection.select_value(
      "SELECT concept_class_id FROM concept_class WHERE name = '#{name}' LIMIT 1"
    )

    return existing if existing

    execute <<-SQL.squish
      INSERT INTO concept_class (name, description, creator, date_created, uuid)
      VALUES ('#{name}', '#{name}', 1, NOW(), UUID())
    SQL

    ActiveRecord::Base.connection.select_value('SELECT LAST_INSERT_ID()')
  end

  def create_answer_set(question_concept_name, answer_concept_names)
    # Get question concept
    question_concept_id = ActiveRecord::Base.connection.select_value(
      "SELECT c.concept_id FROM concept c
       INNER JOIN concept_name cn ON c.concept_id = cn.concept_id
       WHERE cn.name = '#{ActiveRecord::Base.sanitize_sql_for_conditions(question_concept_name)}'
       LIMIT 1"
    )

    return unless question_concept_id

    # Mark question as a set
    execute "UPDATE concept SET is_set = 1 WHERE concept_id = #{question_concept_id}"

    # Add answers
    answer_concept_names.each_with_index do |answer_name, index|
      answer_concept_id = ActiveRecord::Base.connection.select_value(
        "SELECT c.concept_id FROM concept c
         INNER JOIN concept_name cn ON c.concept_id = cn.concept_id
         WHERE cn.name = '#{ActiveRecord::Base.sanitize_sql_for_conditions(answer_name)}'
         LIMIT 1"
      )

      next unless answer_concept_id

      # Create concept answer relationship
      execute <<-SQL.squish
        INSERT INTO concept_answer (concept_id, answer_concept, answer_drug, creator, date_created, uuid, sort_weight)
        VALUES (#{question_concept_id}, #{answer_concept_id}, NULL, 1, NOW(), UUID(), #{index + 1})
        ON DUPLICATE KEY UPDATE sort_weight = #{index + 1}
      SQL
    end
  end
end
