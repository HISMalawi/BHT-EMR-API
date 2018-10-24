# frozen_string_literal: true

class LabPanel < ApplicationRecord
  self.table_name = :map_lab_panel
  self.primary_key = :rec_id

  use_healthdata_db

  # def self.test_name(test_types=nil)
  #   return self.where(["rec_id IN (?)",test_types]).group("rec_id").collect{|n|n.short_name} rescue nil
  # end

  # def self.get_test_type(test_name)
  #   panel_id = self.where(["short_name=?",test_name]).first.rec_id rescue nil
  #   return LabTestType.where(["Panel_ID=?",panel_id]).collect{|types|types.TestType} rescue nil
  # end
end
