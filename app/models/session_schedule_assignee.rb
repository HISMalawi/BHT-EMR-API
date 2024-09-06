class SessionScheduleAssignee < VoidableRecord
    belongs_to :session_schedule
    belongs_to :user
end
