module TBService::Reports::Overview
  class << self
    def statistics (date)
      date = date.to_date

      {
        registration: {
          today: query.by_date(date, 'TB Registration').count,
          year: query.by_year(date.year, 'TB Registration').count
        },
        diagnosis: {
          today: query.by_date(date, 'Diagnosis').count,
          year: query.by_year(date.year, 'Diagnosis').count
        },
        initial_visit: {
          today: query.by_date(date, 'TB_Initial').count,
          year: query.by_year(date.year, 'TB_Initial').count
        },
        lab_order: {
          today: query.by_date(date, 'Lab Orders').count,
          year: query.by_year(date.year, 'Lab Orders').count
        },
        vitals: {
          today: query.by_date(date, 'Vitals').count,
          year: query.by_year(date.year,'Vitals').count
        }
      }
    end

    private
    def query
      TBQueries::EncountersQuery.new
    end
  end
end