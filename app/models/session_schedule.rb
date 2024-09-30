class SessionSchedule < VoidableRecord
    scope :not_voided, -> { where(voided: false) }
    has_many :session_schedule_assignees
    has_many :session_schedule_vaccine

    # Override as_json to fromat  startdate and end_date
    def as_json(options = {})
        super(options).merge(
            start_date: format_date(start_date),
            end_date: format_date(end_date)
        )
    end

    private

    def format_date(date)
      # If date is already a string, parse it to Date
      date = Date.parse(date) if date.is_a?(String)
      
      # Format the date as 'YYYY-MM-DD'
      date.strftime('%Y-%m-%d')
    end
end
