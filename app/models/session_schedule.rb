class SessionSchedule < VoidableRecord
    scope :not_voided, -> { where(voided: false) }
    has_many :session_schedule_assignees
    has_many :session_schedule_vaccine
end
