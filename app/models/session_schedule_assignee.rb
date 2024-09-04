class SessionScheduleAssignee < VoidableRecord
    belongs_to :session_schedule
    has_many :users
end
