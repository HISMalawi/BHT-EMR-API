module TBService::Reports::IptOutcomes
  class << self
    def registered (start_date, end_date)
      ipt_patients_query.all(start_date, end_date)
    end

    def completed (start_date, end_date)
      ipt_patients_query.completed(start_date, end_date)
    end

    private

    def ipt_patients_query
      TBQueries::IptPatientsQuery.new
    end
  end
end