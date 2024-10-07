class Api::V1::SessionScheduleController < ApplicationController

    def index
      session_schedule_vaccines = service.fetch_session_schedules
      render json: session_schedule_vaccines, status: :ok  
    end 
  
    def show
      # Logic for show action (if needed)
    end
  
    def create
      params = get_schedule_session_params 
      
      session_name, start_date, end_date, session_type, repeat,  frequency, assignees =  get_schedule_session_params
      
      session_schedule = service.create_session_schedule(
                                    session_name:, 
                                    start_date:, 
                                    end_date:, 
                                    session_type:, 
                                    repeat:,
                                    frequency:, 
                                    assignees: )

      unless session_schedule.blank?
        render json: session_schedule, status: :ok
      else
        render json: [], status: :ok
      end

    end
  
    def update
      # Logic for update action (if needed)
      session_schedule_id = params[:id]

      session_name, start_date, end_date, session_type, repeat, frequency, assignees = get_schedule_session_params

      session_schedule = service.update_session_schedule(
                                    session_schedule_id:,
                                    session_name:, 
                                    start_date:, 
                                    end_date:, 
                                    session_type:, 
                                    repeat:, 
                                    frequency:,
                                    assignees:)

      unless session_schedule.blank?
        render json: session_schedule, status: :ok
      else
        render json: [], status: :ok
      end

    end  
  
    def destroy
      # Logic for destroy action (if needed)
      session_id =  params[:id]
      void_reason  = params[:void_reason]
      
      begin
        service.void_session_schedule(session_id, void_reason)
        render json: { message: "Session schedule successfully voided",
                       session_schedule_id: session_id }, status: :ok
      rescue => e
        render json: { error: e.message, 
                       session_schedule_id: session_schedule_id}, status: :unprocessable_entity
      end
    end
   
    private

    # Strong params method
    def get_schedule_session_params
      params.require(%i[session_name start_date end_date session_type repeat frequency assignees])
    end

    def service
      ImmunizationService::SessionScheduleService.new
    end


  end
  


  