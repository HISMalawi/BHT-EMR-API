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
      SELECT * from person_names
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
end
