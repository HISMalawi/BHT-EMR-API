class SessionScheduleVaccine < VoidableRecord
    belongs_to :session_schedule
    has_many :drug
end
