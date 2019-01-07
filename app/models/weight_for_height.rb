# frozen_string_literal: true

class WeightForHeight < ApplicationRecord
  self.table_name = 'weight_for_heights'

  def self.patient_weight_for_height_values
    # corrected_height = self.significant(patient_height) #correct height to the neares .5
    all.each_with_object({}) do |hwt, height_for_weight|
      height_for_weight[hwt.supine_cm] = hwt.median_weight_height
    end
  end
end
