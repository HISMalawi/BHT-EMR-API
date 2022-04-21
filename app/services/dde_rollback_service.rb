# frozen_string_literal: true

# this class will basically handle rolling back patients that were merged
class DDERollbackService
  attr_reader :primary_patient, :secondary_patient, :creator

  def initialize(primary:, secondary:)
    @primary_patient = primary
    @secondary_patient = secondary
  end

  # this is the method to rollback patient name
  def rollback_name
    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT * FROM person_name
      WHERE voided = 1
      AND person_id = #{secondary_patient.id}
      AND void_reason = 'Merged into patient ##{primary_patient.patient_id}:#{primary_patient.person.names.first.id}'
    SQL
    return if result.blank?

    @row_id = result.delete('person_name_id')
    remove_common_field(result)
    central_execute_hub('person_name', 'person_name_id')
    handle_model_errors('person name', PersonName.create(result))
  end

  def rollback_identifiers
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM patient_identifier
      WHERE patient_id = #{secondary_patient.id} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient.patient_id}:%'
    SQL
    process_identifiers(voided_identifiers: result)
  end

  def rollback_attributes
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM person_attribute
      WHERE person_id = #{secondary_patient.id} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient.patient_id}:%'
    SQL
    process_attributes(voided_attributes: result)
  end

  def process_identifiers(voided_identifiers: nil)
    return if voided_identifiers.blank?

    voided_identifiers.each do |identifier|
      patient_id, row_id = process_identifiers(identifier['void_reason'])
      record = PatientIdentifier.find_by(patient_identifier_id: row_id, patient_id: patient_id)
      record&.void("Merge Rollback to patient:#{identifier['patient_id']}")
      @row_id = identifier.delete('patient_identifier_id')
      remove_common_field(identifier)
      central_execute_hub('patient_identifier', 'patient_identifier_id')
      handle_model_errors('patient identifier', PatientIdentifier.create(identifier))
    end
  end

  def process_attributes(voided_attributes: nil)
    return if voided_attributes.blank?

    voided_attributes.each do |attribute|
      patient_id, row_id = process_identifiers(attribute['void_reason'])
      record = PersonAttribute.find_by(person_attribute_id: row_id, person_id: patient_id)
      record&.void("Merge Rollback to patient:#{attribute['person_id']}")
      remove_common_field(attribute)
      central_execute_hub('person_attribute', 'person_attribute_id')
      handle_model_errors('person_attribute', PersonAttribute.create(attribute))
    end
  end

  def process_patient_id_and_row_id(reason)
    reason.split('#')[1].split(':')
  end

  def central_execute_hub(table, condition)
    ActiveRecord::Base.connection.execute "UPDATE #{table} SET void_reason = 'Reversed-#{@reason}' WHERE #{condition} = #{@row_id}"
  end

  def remove_common_field(record)
    record.delete('uuid')
    record.delete('voided')
    record.delete('voided_by')
    record.delete('date_voided')
    @reason = record.delete('void_reason')
    record
  end

  def handle_model_errors(activity, local_model)
    raise "Could not rollback #{activity} due to #{local_model.errors.as_json}" unless local_model.errors.blank?
  end
end
