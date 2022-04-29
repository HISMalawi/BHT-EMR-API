# frozen_string_literal: true

# this class will basically handle rolling back patients that were merged
# rubocop:disable Metrics/ClassLength
class DDERollbackService
  attr_reader :primary_patient, :secondary_patient

  def rollback_merged_patient(patient_id)
    tree = MergeAuditService.new.fetch_merge_audit(patient_id)
    ActiveRecord::Base.transaction do
      tree.each do |record|
        @primary_patient = record['primary_id']
        @secondary_patient = record['secondary_id']
        process_rollback
        MergeAudit.find(record['id']).void("Rolling back to #{patient_id}")
      end
    end
    Patient.find(patient_id)
  end

  private

  def process_rollback
    rollback_patient
    rollback_encounter
    rollback_order
    rollback_observation
    rollback_address
    rollback_attributes
    rollback_identifiers
    rollback_name
  end

  # this is the method to rollback patient name
  def rollback_name
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM person_name
      WHERE voided = 1
      AND person_id = #{secondary_patient}
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_name(voided_names: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE person_name SET #{common_void_columns} #{extra_fields}  WHERE person_id = #{common_void_reason}
    SQL
  end

  def rollback_identifiers
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM patient_identifier
      WHERE patient_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_identifiers(voided_identifiers: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE patient_identifier SET #{common_void_columns} WHERE patient_id = #{common_void_reason}
    SQL
  end

  def rollback_attributes
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM person_attribute
      WHERE person_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_attributes(voided_attributes: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE person_attribute SET #{common_void_columns} #{extra_fields} WHERE person_id = #{common_void_reason}
    SQL
  end

  def rollback_address
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM person_address
      WHERE person_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_addresses(voided_addresses: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE person_address SET #{common_void_columns} WHERE person_id = #{common_void_reason}
    SQL
  end

  def rollback_encounter
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM encounter
      WHERE patient_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_encounters(voided_encounters: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE encounter SET #{common_void_columns} #{extra_fields}  WHERE patient_id = #{common_void_reason}
    SQL
  end

  def rollback_observation
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM obs
      WHERE person_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_observations(voided_observations: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE obs SET #{common_void_columns} WHERE person_id = #{common_void_reason}
    SQL
  end

  def rollback_order
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM orders
      WHERE patient_id = #{secondary_patient} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'
    SQL
    process_orders(voided_orders: result)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE orders SET #{common_void_columns} WHERE patient_id = #{common_void_reason}
    SQL
  end

  def rollback_patient
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE patient SET #{common_void_columns} #{extra_fields}  WHERE patient_id = #{common_void_reason}
    SQL
    rollback_person
  end

  def rollback_person
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE person SET #{common_void_columns} #{extra_fields} WHERE person_id = #{common_void_reason}
    SQL
    rollback_patient_program_and_state
    rollback_relationship
  end

  def rollback_patient_program_and_state
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE patient_state ps
      INNER JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id
      SET ps.date_voided = NULL, ps.void_reason = NULL, ps.voided_by = NULL, ps.voided = 0, ps.date_changed = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}', ps.changed_by = #{User.current.id},
      pp.date_voided = NULL, pp.void_reason = NULL, pp.voided_by = NULL, pp.voided = 0, pp.date_changed = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}', pp.changed_by = #{User.current.id}
      WHERE pp.patient_id = #{secondary_patient}
      AND ps.void_reason = 'Merged into patient ##{primary_patient}:0'
      AND pp.void_reason = 'Merged into patient ##{primary_patient}:0'
    SQL
  end

  def rollback_relationship
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE relationship SET #{common_void_columns} WHERE person_a = #{common_void_reason}
    SQL
  end

  def process_name(voided_names: nil)
    return if voided_names.blank?

    voided_names.each do |name|
      patient_id, row_id = process_patient_id_and_row_id(name['void_reason'])
      record = PersonName.find_by(person_name_id: row_id, person_id: patient_id)
      record&.void("Rollback to patient ##{name['person_id']}:#{name['person_name_id']}")
    end
  end

  def process_identifiers(voided_identifiers: nil)
    return if voided_identifiers.blank?

    voided_identifiers.each do |identifier|
      patient_id, row_id = process_patient_id_and_row_id(identifier['void_reason'])
      record = PatientIdentifier.find_by(patient_identifier_id: row_id, patient_id: patient_id)
      record&.void("Rollback to patient ##{identifier['patient_id']}:#{identifier['patient_identifier_id']}")
    end
  end

  def process_attributes(voided_attributes: nil)
    return if voided_attributes.blank?

    voided_attributes.each do |attribute|
      patient_id, row_id = process_patient_id_and_row_id(attribute['void_reason'])
      record = PersonAttribute.find_by(person_attribute_id: row_id, person_id: patient_id)
      record&.void("Rollback to patient ##{attribute['person_id']}:#{attribute['person_attribute_id']}")
    end
  end

  def process_addresses(voided_addresses: nil)
    return if voided_addresses.blank?

    voided_addresses.each do |address|
      patient_id, row_id = process_patient_id_and_row_id(address['void_reason'])
      record = PersonAddress.find_by(person_address_id: row_id, person_id: patient_id)
      record&.void("Rollback to patient ##{address['person_id']}:#{address['person_address_id']}")
    end
  end

  def process_encounters(voided_encounters: nil)
    return if voided_encounters.blank?

    voided_encounters.each do |encounter|
      patient_id, row_id = process_patient_id_and_row_id(encounter['void_reason'])
      record = Encounter.find_by(encounter_id: row_id, patient_id: patient_id)
      record&.void("Rollback to patient ##{encounter['patient_id']}:#{encounter['encounter_id']}")
    end
  end

  def process_observations(voided_observations: nil)
    return if voided_observations.blank?

    voided_observations.each do |obs|
      patient_id, row_id = process_patient_id_and_row_id(obs['void_reason'])
      record = Observation.find_by(obs_id: row_id, person_id: patient_id)
      record&.void("Rollback to patient ##{obs['person_id']}:#{obs['obs_id']}")
    end
  end

  def process_orders(voided_orders: nil)
    return if voided_orders.blank?

    voided_orders.each do |order|
      patient_id, row_id = process_patient_id_and_row_id(order['void_reason'])
      record = Order.find_by(order_id: row_id, patient_id: patient_id)
      record&.void("Rollback to patient ##{order['patient_id']}:#{order['order_id']}")
    end
  end

  def process_patient_id_and_row_id(reason)
    reason.split('#')[1].split(':')
  end

  def remove_common_field(record)
    record.delete('uuid')
    record.delete('voided')
    record.delete('voided_by')
    record.delete('date_voided')
    @reason = record.delete('void_reason')
    record
  end

  def common_void_columns
    @common_void_columns ||= 'date_voided = NULL, void_reason = NULL, voided_by = NULL, voided = 0'
  end

  def extra_fields
    @extra_fields ||= ", date_changed = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}', changed_by = #{User.current.id}"
  end

  def common_void_reason
    @common_void_reason ||= " #{secondary_patient} AND void_reason LIKE 'Merged into patient ##{primary_patient}:%'"
  end
end
# rubocop:enable Metrics/ClassLength
