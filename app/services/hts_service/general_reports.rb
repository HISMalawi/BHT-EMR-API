module HtsService
  class GeneralReports
    def self.daily_statistics
      {
        total_patients_tested_today: total_patients_tested,
      }
    end

    def self.total_patients_tested
      result = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT 
          COUNT(DISTINCT v.patientId) AS unique_patients
        FROM visits v
        INNER JOIN obs o ON v.patientId = o.person_id
        INNER JOIN concept_name c ON c.concept_id = o.concept_id
        WHERE v.programId = 14
          AND c.name IN ('BMI', 'BP')
          AND DATE(v.startDate) = CURDATE();
      SQL

      # Extract value safely depending on adapter
      if result.first.is_a?(Hash)
        result.first['unique_patients']
      else
        result.first[0]
      end
    end
  end
end
