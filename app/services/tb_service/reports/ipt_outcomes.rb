module TbService::Reports::IptOutcomes
  class << self

    def report_format(indicator:)
      {
        indicator: indicator,
        total: []
      }
    end

    def format_report(indicator:, report_data:)
      data = report_format(indicator: indicator)
      report_data&.each do |patient|
        process_patient(patient, data)
      end
      data
    end

    def process_patient(patient, data)
      data[:total] << patient.id unless data[:total].include?(patient.id)
    end

    def registered (start_date, end_date)
      ipt_patients_query.all(start_date, end_date)
    end

    def completed (start_date, end_date)
      ipt_patients_query.completed(start_date, end_date)
    end

    private

    def ipt_patients_query
      TbService::TbQueries::IptPatientsQuery.new
    end
  end
end