class SessionScheduleVaccine < VoidableRecord
    belongs_to :session_schedule
    belongs_to :drug
end
