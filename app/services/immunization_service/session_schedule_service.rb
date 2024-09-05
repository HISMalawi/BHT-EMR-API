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
                                                    repeat:,
                                                    target:)

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
  end
end