# frozen_string_literal: true

class CreateNeonatalConcepts < ActiveRecord::Migration[7.0]
  def up
    # Common neonatal concepts for observations
    concepts = [
      # Triage concepts
      { name: 'Triage priority', datatype: 'Coded', class: 'Finding' },
      { name: 'Emergency', datatype: 'N/A', class: 'Misc' },
      { name: 'Urgent', datatype: 'N/A', class: 'Misc' },
      { name: 'Non-urgent', datatype: 'N/A', class: 'Misc' },
      { name: 'Chief complaint', datatype: 'Text', class: 'Symptom' },

      # Vital signs (these may already exist, but using ON DUPLICATE KEY UPDATE)
      { name: 'Weight (kg)', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Height (cm)', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Temperature (C)', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Pulse', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Respiratory rate', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Systolic blood pressure', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Diastolic blood pressure', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'SPO2', datatype: 'Numeric', class: 'Vital Sign' },

      # Neonatal-specific vital signs
      { name: 'Head circumference', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'Chest circumference', datatype: 'Numeric', class: 'Vital Sign' },
      { name: 'APGAR score', datatype: 'Numeric', class: 'Finding' },

      # Clinical assessment concepts
      { name: 'Diagnosis', datatype: 'Coded', class: 'Diagnosis' },
      { name: 'Birth asphyxia', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Neonatal sepsis', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Neonatal jaundice', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Respiratory distress syndrome', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Prematurity', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Low birth weight', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Congenital anomaly', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Hypothermia', datatype: 'N/A', class: 'Diagnosis' },
      { name: 'Hypoglycemia', datatype: 'N/A', class: 'Diagnosis' },

      # Birth information
      { name: 'Birth weight', datatype: 'Numeric', class: 'Finding' },
      { name: 'Birth length', datatype: 'Numeric', class: 'Finding' },
      { name: 'Gestational age', datatype: 'Numeric', class: 'Finding' },
      { name: 'Mode of delivery', datatype: 'Coded', class: 'Finding' },
      { name: 'Vaginal delivery', datatype: 'N/A', class: 'Misc' },
      { name: 'Caesarean section', datatype: 'N/A', class: 'Misc' },
      { name: 'Multiple birth', datatype: 'Boolean', class: 'Finding' },
      { name: 'Birth order', datatype: 'Numeric', class: 'Finding' },

      # Feeding
      { name: 'Feeding method', datatype: 'Coded', class: 'Finding' },
      { name: 'Exclusive breastfeeding', datatype: 'N/A', class: 'Misc' },
      { name: 'Mixed feeding', datatype: 'N/A', class: 'Misc' },
      { name: 'Formula feeding', datatype: 'N/A', class: 'Misc' },
      { name: 'Nasogastric feeding', datatype: 'N/A', class: 'Misc' },

      # Treatment concepts
      { name: 'Medication orders', datatype: 'Coded', class: 'Misc Order' },
      { name: 'Procedures', datatype: 'Coded', class: 'Procedure' },
      { name: 'Phototherapy', datatype: 'N/A', class: 'Procedure' },
      { name: 'Oxygen therapy', datatype: 'N/A', class: 'Procedure' },
      { name: 'IV fluids', datatype: 'N/A', class: 'Procedure' },
      { name: 'Kangaroo mother care', datatype: 'N/A', class: 'Procedure' },

      # Appointment concepts
      { name: 'Appointment date', datatype: 'Date', class: 'Misc' },
      { name: 'Follow-up instructions', datatype: 'Text', class: 'Misc' },

      # Outcome concepts
      { name: 'Visit outcome', datatype: 'Coded', class: 'Finding' },
      { name: 'Discharged home', datatype: 'N/A', class: 'Misc' },
      { name: 'Admitted', datatype: 'N/A', class: 'Misc' },
      { name: 'Referred', datatype: 'N/A', class: 'Misc' },
      { name: 'Died', datatype: 'N/A', class: 'Misc' },
      { name: 'Absconded', datatype: 'N/A', class: 'Misc' },

      # Additional enrollment concepts
      { name: 'Mother identifier', datatype: 'Text', class: 'Misc' },
      { name: 'Place of birth', datatype: 'Text', class: 'Finding' },
      { name: 'Time of birth', datatype: 'Time', class: 'Finding' },
      { name: 'Complications at birth', datatype: 'Text', class: 'Finding' }
    ]

    concepts.each do |concept_data|
      create_or_update_concept(
        concept_data[:name],
        concept_data[:datatype],
        concept_data[:class]
      )
    end

    # Create answer sets for coded concepts
    create_answer_set('Triage priority', %w[Emergency Urgent Non-urgent])
    create_answer_set('Mode of delivery', ['Vaginal delivery', 'Caesarean section'])
    create_answer_set('Feeding method', ['Exclusive breastfeeding', 'Mixed feeding', 'Formula feeding', 'Nasogastric feeding'])
    create_answer_set('Visit outcome', ['Discharged home', 'Admitted', 'Referred', 'Died', 'Absconded'])
  end

  def down
    # Remove concepts (this will be complex due to relationships, so we'll just mark as retired)
    concept_names = [
      'Triage priority', 'Emergency', 'Urgent', 'Non-urgent', 'Chief complaint',
      'Head circumference', 'Chest circumference', 'APGAR score',
      'Birth asphyxia', 'Neonatal sepsis', 'Neonatal jaundice',
      'Respiratory distress syndrome', 'Prematurity', 'Low birth weight',
      'Congenital anomaly', 'Hypothermia', 'Hypoglycemia',
      'Birth weight', 'Birth length', 'Gestational age', 'Mode of delivery',
      'Vaginal delivery', 'Caesarean section', 'Multiple birth', 'Birth order',
      'Feeding method', 'Exclusive breastfeeding', 'Mixed feeding',
      'Formula feeding', 'Nasogastric feeding', 'Phototherapy',
      'Oxygen therapy', 'IV fluids', 'Kangaroo mother care',
      'Follow-up instructions', 'Visit outcome', 'Discharged home',
      'Admitted', 'Referred', 'Died', 'Absconded',
      'Mother identifier', 'Place of birth', 'Time of birth',
      'Complications at birth'
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
