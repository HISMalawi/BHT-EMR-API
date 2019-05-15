# frozen_string_literal: true

module ANCService
  class DataCleaning

    FIRST_VISIT_ENC = ["VITALS", "APPOINTMENT", "ART_FOLLOWUP",
            "TREATMENT", "MEDICAL HISTORY", "LAB RESULTS", "UPDATE OUTCOME",
            "DISPENSING", "ANC EXAMINATION", "CURRENT PREGNANCY",
            "OBSTETRIC HISTORY", "SURGICAL HISTORY", "SOCIAL HISTORY",
            "ANC VISIT TYPE"]

    SUBSEQ_VISIT_ENC = ["VITALS", "APPOINTMENT", "ART_FOLLOWUP", "TREATMENT",
            "LAB RESULTS", "UPDATE OUTCOME", "DISPENSING", "ANC VISIT TYPE"]

    def initialize(start_date, end_date)
      @start_date = start_date.to_date
      @end_date = end_date.to_date
    end

    def incomplete_visits
      @incomplete_visits = []
      query = "SELECT DATE(encounter_datetime) visit_date,
        GROUP_CONCAT(DISTINCT(e.encounter_type)) AS et,
        e.patient_id,
		(SELECT COUNT(DISTINCT(DATE(encounter_datetime))) FROM encounter
			WHERE patient_id = e.patient_id
        AND voided = 0
        AND DATE(encounter_datetime) <= DATE(e.encounter_datetime)
        AND program_id = 12
			) visit_no
        FROM encounter e WHERE Date(e.encounter_datetime) >= '#{@start_date}'
        AND Date(e.encounter_datetime) <= '#{@end_date}'
        AND voided = 0 AND program_id = 12
        GROUP BY e.patient_id, visit_date"
    visits = ActiveRecord::Base.connection.select_all(query)
    visits.each do |v|
            all_et = FIRST_VISIT_ENC
            patient_et =  v['et'].split(',')
            patient_et = patient_et.map{|n|eval n}
            a = all_et.to_set.subset?(patient_et.to_set)
            if !a == true
              patient_name = Person.find(v['patient_id']).name
              national_id = PatientIdentifier.find_by_patient_id(v['patient_id']).identifier
              visit_hash = {"name"=> patient_name,
                          "n_id"=>national_id,
                          "visit_no"=> v['visit_no'],
                          "visit_date"=>v['visit_date'].to_date.strftime("%d/%m/%Y"),
                          "patient_id"=> v['patient_id']
                        }

              @incomplete_visits << visit_hash
            else

            end
    end
      return @incomplete_visits
    end

  end

end