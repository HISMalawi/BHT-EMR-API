# frozen_string_literal: true

class LabTestTable < ApplicationRecord
  self.table_name = 'LabTestTable'
  self.primary_key = 'AccessionNum'

  has_many :lab_samples, foreign_key: :AccessionNum

  use_healthdata_db

  def as_json(options = {})
    super(options.merge(
      include: {
        lab_samples: {
          include: :lab_parameters
        }
      }
    ))
  end
end
