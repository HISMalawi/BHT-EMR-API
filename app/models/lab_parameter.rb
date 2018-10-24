# frozen_string_literal: true

class LabParameter < ApplicationRecord
  self.table_name = 'Lab_Parameter'
  self.primary_key = 'ID'

  use_healthdata_db

  belongs_to :lab_sample, foreign_key: :sample_id, optional: true

  # def self.find_by_sample_id(sample_id)
  #   return LabParameter.where(["sample_id =?", sample_id])
  # end

  # def self.find_cd4_test_by_sample_id(sample_id)
  #   test_types = LabTestType.where(["(testname=? or testname=?)","CD4_count","CD4_percent"]).collect{|type|type.TestType} rescue nil
  #   return self.where(["Sample_ID=? and (testtype=? or testtype=?)",sample_id,test_types.first,test_types.last]) rescue nil
  # end

  # def self.find_lab_test_by_sample_id_test_type(sample_id,test_types)
  #   return self.where(["Sample_ID=? and testtype IN (?)",sample_id,test_types]) rescue nil
  # end
end
