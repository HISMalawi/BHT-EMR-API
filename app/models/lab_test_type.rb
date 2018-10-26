# frozen_string_literal: true

class LabTestType < ApplicationRecord
  self.table_name = :codes_TestType
  self.primary_key = :ID

  use_healthdata_db


  belongs_to :lab_panel, foreign_key: :Panel_ID

  # def self.test_name(test_type)
  #   LabTestType.where(['TESTTYPE=?', test_type.to_i]).first.TestName
  # rescue StandardError
  #   nil
  # end

  # def self.test_type_by_name(test_type)
  #   panel_id = begin
  #                LabTestType.where(['TestName=?', test_type]).first.Panel_ID
  #              rescue StandardError
  #                nil
  #              end
  #   begin
  #      return LabPanel.test_name(panel_id).to_s
  #    rescue StandardError
  #      nil
  #    end
  # end

  # def self.available_test
  #   all.map(&:TestName)
  # end
end
