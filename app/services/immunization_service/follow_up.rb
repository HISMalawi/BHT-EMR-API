module ImmunizationService
  class FollowUp
    
    # Immunization program ID
    PROGRAM_ID = 33

    def initialize
    end

    # Fetch all missed immunizations or milestones 
    def fetch_missed_immunizations(location_id)
      immunization_clients = Patient.joins(:encounters, person: :names)
                                    .where("encounter.program_id = ? AND patient.voided = ? AND encounter.location_id = ?", 
                                            PROGRAM_ID, false, location_id)
                                    .distinct
                                    .pluck("patient.patient_id, person.birthdate, person_name.given_name, person_name.family_name")


      under_five_missed_visits = []
      over_five_missed_visits = []
      under_five_count = 0
      over_five_count = 0

      immunization_clients.each do |patient_id, birthdate, given_name, family_name|
        immunization_client = OpenStruct.new(patient_id: patient_id, birthdate: birthdate, given_name: given_name, family_name: family_name)

        vaccine_schedules = ImmunizationService::VaccineScheduleService.vaccine_schedule(find_patient(immunization_client.patient_id))

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
          if age_in_years(immunization_client.birthdate) < 5
            under_five_missed_visits << { client: immunization_client, missed_visits: client_missed_visits }
            under_five_count += 1
          else
            over_five_missed_visits << { client: immunization_client, missed_visits: client_missed_visits }
            over_five_count += 1
          end
        end
      end


      { under_five_missed_visits: under_five_missed_visits, over_five_missed_visits: over_five_missed_visits, 
        under_five_count: under_five_count, over_five_count: over_five_count }
    end

    # Count total clients with missed vaccines
    def over_due_stats
      missed_visits = fetch_missed_immunizations
      {
        under_five: missed_visits[:under_five_count],
        over_five: missed_visits[:over_five_count]
      }
    end

    def age_in_years(birthdate)
      today = Date.today
      age = today.year - birthdate.year
      age -= 1 if today.month < birthdate.month || (today.month == birthdate.month && today.day < birthdate.day)
      age
    end

    def find_patient(patient_id)
      Person.find(patient_id)
    end
  end
end
