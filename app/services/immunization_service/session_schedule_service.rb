module ImmunizationService
  class SessionScheduleService
    def initialize
      # Initialization logic if needed
    end

    def create_session_schedule(session_name:, start_date:, end_date:, session_type:, repeat:, frequency:, assignees:)
      session_schedule = nil

      SessionSchedule.transaction do
        session_schedule = create_schedule(session_name, start_date, end_date, session_type, repeat, frequency)
        create_assignees(session_schedule.id, assignees)
      end

      unless session_schedule.blank?

        # Convert session_schedule to a hash and add custom attributes
        session_schedule_data = session_schedule.as_json
        session_schedule_data[:session_vaccines] =  get_session_vaccines
        
        return session_schedule_data
      end
    end

    def update_session_schedule(session_schedule_id:, session_name:, start_date:, end_date:, session_type:, repeat:, 
                                frequency:, assignees:)
      current_time = Time.current
      voided_by = User.current.id

      SessionSchedule.transaction do
        # Find and update the session schedule details
        session_schedule = SessionSchedule.where(session_schedule_id:).update!(
                                                                  session_name:,
                                                                  start_date:,
                                                                  end_date:, 
                                                                  session_type:,
                                                                  repeat_type: repeat,
                                                                  frequency:
                                                                )

        handle_assignees(session_schedule_id, assignees, current_time, voided_by)

        session_schedule

      end
    end

    def fetch_session_schedules
      session_schedules = SessionSchedule.not_voided
                                         .where(location_id: User.current.location_id)
                                         .includes(session_schedule_assignees: {user: { person: :names} })
      session_vaccines = get_session_vaccines

      session_schedules.map do |session_schedule|
        session_schedule_data = session_schedule.as_json(only: [:session_schedule_id,
                                                                :session_name,
                                                                :session_type, :repeat_type, :frequency ])
        
        
        session_schedule_data[:assignees] = get_session_assignees(session_schedule)
        session_schedule_data[:session_vaccines] = session_vaccines
        session_schedule_data
      end
    end

     

    def void_session_schedule(session_id, reason)
      current_time = Time.current

      SessionSchedule.transaction do
        void_records(SessionSchedule, session_id, reason, current_time)
        void_records(SessionScheduleAssignee, session_id, nil, current_time)
      end
    end

    private

    def create_schedule(session_name, start_date, end_date, session_type, repeat_type, frequency)
      SessionSchedule.create!(
        session_name:,
        start_date:,
        end_date:,
        session_type:,
        repeat_type:,
        frequency:,
        location_id: User.current.location_id
      )
    end

    # Creates associated assignees for the session schedule
    def create_assignees(session_schedule_id, assignees)
      assignees.each do |user_id|
        SessionScheduleAssignee.create!(
          session_schedule_id: session_schedule_id,
          user_id: user_id
        )
      end
    end

    # Helper method to retrieve assignees from preloaded data
    def get_session_assignees(session_schedule)
      session_schedule.session_schedule_assignees.map do |assignee|
        user = assignee.user
        person_name = user.person.names.first
        {
          assignee_id: assignee.id,
          user_id: user.user_id,
          username: user.username,
          given_name: person_name.given_name,
          family_name: person_name.family_name
        }
      end
    end

    def get_session_vaccines
      unique_clients = {}
      vaccines_list = []
      total_missed_doses = 0

      immunization_data = get_immunization_data

      immunization_data.each do |datum|

        under_five_missed_doses = datum.value['under_five_missed_doses'] || []

        under_five_missed_doses.each do |dose|
          # Track unique clients by patient
          dose['clients'].each do |client| 
            patient_id = client['table']['patient_id']
            unique_clients[patient_id] = true
          end

          vaccines_list << { drug_id:  dose['drug_id'], 
                             drug_name: dose['drug_name'],
                             missed_doses: dose['missed_doses'] }

          total_missed_doses += dose['missed_doses']
        end
      end

      total_unique_clients =  unique_clients.keys.size

      # Return the results
      {
        total_clients: total_unique_clients,
        vaccines: vaccines_list,
        total_missed_doses: total_missed_doses
      }
    end

    # Handles changes to assignees, including voiding old ones and adding new ones
    def handle_assignees(session_schedule_id, assignees, current_time, voided_by)
      existing_assignee_ids = session_schedule_assignees(session_schedule_id).pluck(:user_id)
      if assignees.sort != existing_assignee_ids.sort
        void_and_replace_assignees(session_schedule_id, assignees, current_time, voided_by)
      end
    end

    # Marks records as voided with a reason and timestamp
    def void_records(model, session_id, reason, current_time)
      updates = { voided: true, date_voided: current_time, voided_by: User.current.id }
      updates[:void_reason] = reason if reason.present?

      model.where(session_schedule_id: session_id).update_all(updates)
    end

    # Voids old assignees and adds new ones
    def void_and_replace_assignees(session_schedule_id, assignees, current_time, voided_by)
      void_records(SessionScheduleAssignee, session_schedule_id, nil,  current_time)
      assignees.each do |assignee_id|
        SessionScheduleAssignee.create!(session_schedule_id: session_schedule_id, user_id: assignee_id)
      end
    end

    # Fetches existing assignees for a session schedule
    def session_schedule_assignees(session_schedule_id)
      SessionScheduleAssignee.where(session_schedule_id: session_schedule_id)
    end


    def get_immunization_data
      location_id = User.current.location_id
      ImmunizationCacheDatum.where(name: "missed_immunizations", location_id: location_id)
    end

  end
end
