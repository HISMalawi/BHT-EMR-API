# frozen_string_literal: true

class TbService::PatientVitalStats
  delegate :get, to: :patient_observation

  def initialize (patient)
    @patient = patient
  end

  def height
    c_name = 'Height (cm)'
    get(@patient, c_name).first&.value_numeric || 0
  end

  def weight
    c_name = 'Weight'
    get(@patient, c_name).first&.value_numeric || 0
  end

  def bmi
    c_name = 'BMI'
    get(@patient, c_name).first&.value_numeric || 0
  end

  private

  def patient_observation
    TbService::PatientObservation
  end
end