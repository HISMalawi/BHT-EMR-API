class SessionSchedule < VoidableRecord
    scope :not_voided, -> { where(voided: false) }
    has_many :session_schedule_assignees
    has_many :session_schedule_vaccine
  
    before_save :format_dates_for_saving
  
    def as_json(options = {})
      super(options).merge(
        start_date: format_date(start_date, 'MM/DD/YYYY'),
        end_date: format_date(end_date, 'MM/DD/YYYY')
      )
    end
  
    private
  
    def format_date(date, format = 'YYYY-MM-DD')
      # Ensure date is a Date object
      date = Date.parse(date) if date.is_a?(String)
  
      case format
      when 'YYYY-MM-DD'
        date.strftime('%Y-%m-%d') if date
      when 'MM/DD/YYYY'
        date.strftime('%m/%d/%Y') if date
      else
        date.strftime('%Y-%m-%d') # Default to 'YYYY-MM-DD'
      end
    end
  
    def format_dates_for_saving
      self.start_date = format_date(start_date, 'YYYY-MM-DD') if start_date.present?
      self.end_date = format_date(end_date, 'YYYY-MM-DD') if end_date.present?
    end
  end
  