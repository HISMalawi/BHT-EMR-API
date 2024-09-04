class SessionSchedule < VoidableRecord
    has_many :session_schedule_assignee
    has_many :session_schedule_vaccine
end
