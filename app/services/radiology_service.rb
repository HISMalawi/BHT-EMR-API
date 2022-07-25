# frozen_string_literal: true

# Radiology Service class to be managing the radiology common tasks
class RadiologyService
  def initialize(patient)
    @patient = patient
  end

  def radiology_orders
    @patient.encounters.where(['encounter_type = ?', EncounterType.find_by_name('RADIOLOGY').id]).collect do |e|
      e.observations.collect { |o| o.answer_string }.join(', ')
    end.join('; ')
  end
end
