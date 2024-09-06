module ImmunizationService
  class SessionScheduleService
    def initialize
      
    end

    def create_session_schedule(session_name:, start_date:, end_date:, session_type:, repeat:, 
      assignees:, vaccines_ids:, target: )

      session_schedule = nil 


      SessionSchedule.transaction do 
        session_schedule = SessionSchedule.create!(session_name:, 
                                                    start_date: , 
                                                    end_date:,
                                                    session_type:,
                                                    repeat_type: repeat,
                                                    target:,
                                                    location_id: User.current.location_id)

        assignees.each do |assignee_id|
          SessionScheduleAssignee.create!(
            session_schedule_id: session_schedule.session_schedule_id,
            user_id: assignee_id 
          )
        end

        vaccines_ids.each do |vaccine_id|
          SessionScheduleVaccine.create!(
            session_schedule_id: session_schedule.session_schedule_id,
            drug_id: vaccine_id
          )
        end
      end

      session_schedule
    end

    def fetch_session_schedules
      session_schedules = SessionSchedule.select("session_schedules.*")
                                         .where(voided: false, location_id: User.current.location_id)
    
      # Transform the session schedules into a format that allows extra fields
      session_schedules.map do |session_schedule|
        session_schedule_data = session_schedule.as_json
    
        # Add assignees and vaccines as additional keys to the serialized session schedule
        session_schedule_data[:assignees] = get_session_assignees(session_schedule.session_schedule_id)
        session_schedule_data[:vaccines] = get_session_vaccines(session_schedule.session_schedule_id)
    
        session_schedule_data
      end
    end
    
    private
    
    def get_session_assignees(session_schedule_id)
      SessionScheduleAssignee.joins(user: { person: :names })
                             .select('session_schedule_assignees.*, users.user_id, users.username,
                              person_name.given_name, person_name.family_name')
                             .where(session_schedule_id: session_schedule_id).where(voided: false)
    end
    
    def get_session_vaccines(session_schedule_id)
      SessionScheduleVaccine.joins(:drug)
                            .select('session_schedule_vaccines.*, drug.name, drug.drug_id')
                            .where(session_schedule_id: session_schedule_id).where(voided: false)
    end    
    
  end
end