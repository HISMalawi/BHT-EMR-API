class Lab < ApplicationRecord
  self.table_name = :map_lab_panel

  use_healthdata_db

#   def self.results(patient, patient_ids)
#     results = self.find_by_sql(["
# SELECT * FROM Lab_Sample s
# INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
# INNER JOIN codes_TestType c ON p.testtype = c.testtype
# INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
# WHERE s.patientid IN (?)
# AND s.deleteyn = 0
# AND s.attribute = 'pass'
# GROUP BY short_name ORDER BY m.short_name",patient_ids
#       ]).collect do | result |
#       [
#         result.short_name,
#         result.TestName,
#         result.Range,
#         result.TESTVALUE,
#         result.TESTDATE
#       ]
#     end

#     return if results.blank?
#     results
#   end

#   def self.results_by_type(patient, type, patient_ids)
#     results_hash = {}
#     results = self.find_by_sql(["
# SELECT * FROM Lab_Sample s
# INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
# INNER JOIN codes_TestType c ON p.testtype = c.testtype
# INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
# WHERE s.patientid IN (?)
# AND short_name = ?
# AND s.deleteyn = 0
# AND s.attribute = 'pass'
# ORDER BY DATE(TESTDATE) DESC",patient_ids,type
#       ]).collect do | result |
#       test_date = result.TESTDATE.to_date rescue ''
#       if results_hash[result.TestName].blank?
#         results_hash["#{test_date}::#{result.TestName}"] = { "Range" => nil , "TestValue" => nil }
#       end
#       results_hash["#{test_date}::#{result.TestName}"] = { "Range" => result.Range , "TestValue" => result.TESTVALUE }
#     end

#     return if results_hash.blank?
#     results_hash
#   end

#   def self.latest_result_by_test_type(patient,test_type,patient_ids)
#     results = self.results_by_type(patient, test_type, patient_ids)             
#     unless results.blank?                                                       
#       return results.sort{|a,b|b[0].split("::")[0].to_date <=> a[0].split("::")[0].to_date}[0]
#     else                                                                        
#       return []                                                                 
#     end                                                                         
#   end

#   def self.latest_viral_load_result(patient)
#     patient_identifiers = LabController.new.id_identifiers(patient)
#     results = Lab.latest_result_by_test_type(patient, 'HIV_viral_load', patient_identifiers) rescue nil
#     latest_date = results[0].split('::')[0].to_date rescue nil
#     latest_result = results[1]["TestValue"] rescue nil
#     modifier = results[1]["Range"] rescue nil
#     vl_result = {:latest_result => latest_result, :latest_date => latest_date, :modifier => modifier}
#     return vl_result
#   end
end
