require './app/services/immunization_service/vaccine_schedule_service'

module Api 
  module V1 
    class ImmunizationFollowUpController < ApplicationController
      
      def missed_immunizations
        immunization_clients = Patient.joins(:encounters).distinct.select("patient.patient_id")
                                .where("encounter.program_id = ? and
                                 patient.voided = ? and encounter.location_id = ?", 
                                33, false, User.current.location_id)

        missed_visits = []

        immunization_clients.each do |immunization_client|
          vaccine_schedules = VaccineScheduleService.vaccine_schedule(immunization_client.person)

          client_missed_visits = []

          vaccine_schedules.each do |vaccine_schedule|
            vaccine_schedule[1].each do |visit|
              missed_antigens = visit[:antigens].select do |antigen|
                antigen[:can_administer] && antigen[:status] == "pending"
              end
              
              unless missed_antigens.empty?
                client_missed_visits << { 
                  visit: visit[:visit], 
                  milestone_status: visit[:milestone_status],
                  age: visit[:age],
                  antigens: missed_antigens }
              end
            end
          end

          unless client_missed_visits.empty?
            missed_visits << { client: immunization_client, missed_visits: client_missed_visits }
          end
        end

        render json: missed_visits, status: :ok
      end

    end
  end
end
