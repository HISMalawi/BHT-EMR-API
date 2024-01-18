module TBService::Reports::Overview
  class << self
    def statistics (date)
      date = date.to_date

      {
        registration: {
          today: query.by_date(date, 'TB Registration').count
        },
        diagnosis: {
          today: query.by_date(date, 'Diagnosis').count
        },
        initial_visit: {
          today: query.by_date(date, 'TB_Initial').count
        },
        lab_order: {
          today: query.by_date(date, 'Lab Orders').count
        },
        vitals: {
          today: query.by_date(date, 'Vitals').count
        },
        treatment: {
          today: query.by_date(date, 'Treatment').count
        }
      }
    end

    private
    def query
      TbQueries::EncountersQuery.new
    end
  end
end