class SessionSchedule < VoidableRecord
    scope :not_voided, -> { where(voided: false) }
    has_many  :session_schedule_assignees
    has_many  :session_schedule_vaccine
    validates :session_name, presence: true
    validates :start_date, presence: true
    validates :end_date, presence: true
    validates :session_type, presence: true
    validates :repeat_type, presence: true
  end
  