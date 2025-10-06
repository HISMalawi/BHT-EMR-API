module HtsService
  class GeneralReports
    def self.daily_statistics
      {
        total_patients_tested_today: total_patients_tested(
        program_id: 14,
        concept_names: ['BMI', 'BP'],
        date: Date.today.to_s),
        total_patients_enrolled_in_htc: total_patients_enrolled_in_htc
      }
    end

    def self.total_patients_enrolled_in_htc
      result = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT COUNT(*) AS total_patients FROM visits WHERE programId = 14 AND DATE(visits.startDate)= '#{Date.today.to_s}';
      SQL
      if result.first.is_a?(Hash)
        result.first['total_patients']
      else
        result.first[0]
      end
    end

    def self.total_patients_tested(program_id:, concept_names:, date:)
      names_list = concept_names.map { |name| ActiveRecord::Base.connection.quote(name) }.join(", ")

      result = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT 
          COUNT(DISTINCT v.patientId) AS unique_patients
        FROM visits v
        INNER JOIN obs o ON v.patientId = o.person_id
        INNER JOIN concept_name c ON c.concept_id = o.concept_id
        WHERE v.programId = #{program_id}
          AND c.name IN (#{names_list})
          AND DATE(v.startDate) = '#{date}';
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
