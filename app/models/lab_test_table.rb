# frozen_string_literal: true

class LabTestTable < ApplicationRecord
  self.table_name = 'LabTestTable'
  self.primary_key = 'AccessionNum'

  has_one :lab_sample, foreign_key: :AccessionNum

  use_healthdata_db

  def as_json(options = {})
    super(options.merge(
      include: {
        lab_sample: {
          include: {
            lab_parameter: {
              include: {
                test_type: {}
              }
            }
          }
        }
      }
    ))
  end
end
