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
    result = ActiveRecord::Base.connect.select_one <<~SQL
      SELECT * FROM person_names
      WHERE voided = 1
      AND person_id = #{secondary_patient.id}
      AND void_reason = 'Merged into patient ##{primary_patient.patient_id}:#{primary_patient.person.names.first.id}'
    SQL
    return if result.blank?

    result.delete('uuid')
    result.delete('person_name_id')
    result.delete('creator')

    PersonName.create(result)
  end

  def rollback_identifiers
    result = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT * FROM patient_identifier
      WHERE patient_id = #{secondary_patient.id} AND voided = 1
      AND void_reason LIKE 'Merged into patient ##{primary_patient.patient_id}:%'
    SQL
  end

  def process_identifiers(voided_identifiers: nil)
    return if voided_identifiers.blank?

    voided_identifiers.each do |identifier|
      process_identifiers(identifier['void_reason'])
    end
  end

  def process_patient_id_and_row_id(reason)
    patient_id, row_id = reason.split('#')[1].split(':')
    { patient: patient_id.to_i, row: row_id.to_i }
  end
end
