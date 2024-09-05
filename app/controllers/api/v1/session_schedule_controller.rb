class Api::V1::SessionScheduleController < ApplicationController

    def index
      # Logic for index action (if needed)
    end 
  
    def show
      # Logic for show action (if needed)
    end
  
    def create
      params = get_schedule_session_params 
      
      session_name, start_date, end_date, session_type, repeat, assignees = params
      
      immunization_data = get_immunization_data
  
      # Get overdue vaccine IDs and target count using the fetched immunization data
      vaccines_ids = get_over_due_vaccines_ids(immunization_data)
      target = get_target_count(immunization_data)
        
      session_schedule = service.create_session_schedule(
                                    session_name:, 
                                    start_date:, 
                                    end_date:, 
                                    session_type:, 
                                    repeat:, 
                                    assignees:, 
                                    vaccines_ids:,
                                    target: )
      unless session_schedule.blank?
        render json: session_schedule, status: :ok
      else
        render json: {}, status: :unprocessable_entity
      end

    end
  
    def update
      # Logic for update action (if needed)
    end 
  
    def destroy
      # Logic for destroy action (if needed)
    end
  
    # Method to get overdue vaccine IDs
    def get_over_due_vaccines_ids(immunization_data)
      vaccine_ids = []
  
      immunization_data.each do |datum|
        under_five_missed_doses = datum.value['under_five_missed_doses'] || []
        over_five_missed_doses = datum.value['over_five_missed_doses'] || []
  
        # Collect unique vaccine_ids from under_five and over_five overdue lists
        under_five_missed_doses.each do |dose|
          drug_id = dose['drug_id']
          vaccine_ids << drug_id unless vaccine_ids.include?(drug_id)
        end
  
        over_five_missed_doses.each do |dose|
          drug_id = dose['drug_id']
          vaccine_ids << drug_id unless vaccine_ids.include?(drug_id)
        end
      end
  
      vaccine_ids
    end
  
    # Method to get target count (under and over five overdue counts)
    def get_target_count(immunization_data)
      total_count = 0

      immunization_data.each do |datum|
        under_five_missed_doses = datum.value['under_five_missed_doses'] || []
        over_five_missed_doses = datum.value['over_five_missed_doses'] || []
  
        # Count the total missed doses
        total_count += under_five_missed_doses.size
        total_count += over_five_missed_doses.size
      end
  
      total_count
    end
  
    private
  
    # Method to fetch immunization data based on current location
    def get_immunization_data
      location_id = User.current.location_id
      ImmunizationCacheDatum.where(name: "missed_immunizations", location_id: location_id)
    end
  
    # Strong params method
    def get_schedule_session_params
      params.require(%i[session_name start_date end_date session_type repeat assignees])
    end

    def service
        ImmunizationService::SessionScheduleService.new
    end


  end
  


  