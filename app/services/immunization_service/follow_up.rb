require 'date'

module ImmunizationService
  class FollowUp
    
    # Immunization program ID
    PROGRAM_ID = 33

    def initialize
    end

    # Fetch all missed immunizations or milestones 
    def fetch_missed_immunizations(location_id)
      immunization_clients = fetch_immunization_clients(location_id)
      today = Date.today
      start_of_week = today - today.wday
      end_of_week = start_of_week + 6
      start_of_month = Date.new(today.year, today.month, 1)
      end_of_month = Date.new(today.year, today.month, -1)

      due_today,  due_this_week,  due_this_month = [], [], []
      under_five_missed_visits, over_five_missed_visits, under_five_count, over_five_count = [], [], 0, 0
      under_five_missed_doses, over_five_missed_doses = [], []

      immunization_clients.each do |patient_id, birthdate, given_name, family_name|
        immunization_client = OpenStruct.new(patient_id: patient_id, birthdate: birthdate, given_name: given_name, family_name: family_name)
        client_missed_visits, vaccine_schedules = [], ImmunizationService::VaccineScheduleService.vaccine_schedule(find_patient(patient_id))

        process_vaccine_schedules(vaccine_schedules, client_missed_visits, under_five_missed_doses,
                                  over_five_missed_doses, due_today, due_this_week, due_this_month,
                                  today, start_of_week, end_of_week, start_of_month, end_of_month, immunization_client)

        if client_missed_visits.any?
          if age_in_years(immunization_client.birthdate) < 5
            under_five_missed_visits << { client: immunization_client, missed_visits: client_missed_visits }
            under_five_count += 1
          else
            over_five_missed_visits << { client: immunization_client, missed_visits: client_missed_visits }
            over_five_count += 1
          end
        end
      end

      {
        under_five_missed_visits: under_five_missed_visits,
        over_five_missed_visits: over_five_missed_visits,
        under_five_count: under_five_count,
        over_five_count: over_five_count,
        under_five_missed_doses: under_five_missed_doses,
        over_five_missed_doses: over_five_missed_doses,
        due_today_count: due_today.count,
        due_this_week_count: due_this_week.count,
        due_this_month_count: due_this_month.count,
        due_today: due_today,
        due_this_week: due_this_week,
        due_this_month: due_this_month
      }
    end

    # Count total clients with missed vaccines
    def over_due_stats(location_id)
      missed_visits = fetch_missed_immunizations(location_id)
      {
        under_five: missed_visits[:under_five_count],
        over_five: missed_visits[:over_five_count],
        under_five_missed_doses: missed_visits[:under_five_missed_doses],
        over_five_missed_doses: missed_visits[:over_five_missed_doses]
      }
    end

    private

    # Fetch clients eligible for immunization follow-up
    def fetch_immunization_clients(location_id)
      Patient.joins(:encounters, person: :names)
             .where("encounter.program_id = ? AND patient.voided = ? AND encounter.location_id = ?", PROGRAM_ID, false, location_id)
             .distinct
             .pluck("patient.patient_id, person.birthdate, person_name.given_name, person_name.family_name")
    end

    # Process vaccine schedules and determine missed doses
    def process_vaccine_schedules(vaccine_schedules, client_missed_visits, under_five_missed_doses,
       over_five_missed_doses, due_today, due_this_week, due_this_month, today, start_of_week,
       end_of_week, start_of_month, end_of_month, immunization_client)

      vaccine_schedules.each do |vaccine_schedule|
        vaccine_schedule[1].each do |visit|

          missed_antigens = visit[:antigens].select { |antigen| antigen[:can_administer] && antigen[:status] == "pending" && visit[:milestone_status] == "passed" }

          unless missed_antigens.empty?
            client_missed_visits << { visit: visit[:visit], milestone_status: visit[:milestone_status], age: visit[:age], antigens: missed_antigens }
            update_missed_doses(missed_antigens, immunization_client.birthdate, under_five_missed_doses, over_five_missed_doses)

            # Calculate if the vaccine can be admnistered and its pending 
          end

          due_antigens = visit[:antigens].select { |antigen| antigen[:can_administer] && antigen[:status] == "pending" && visit[:milestone_status] == "current"}

          unless due_antigens.empty?
            due_date = calculate_due_date(immunization_client.birthdate, visit[:age])

            if due_date == today
              due_today << { client: immunization_client, antigens: due_antigens }
            elsif due_date >= start_of_week && due_date <= end_of_week
              due_this_week << { client: immunization_client, antigens: due_antigens }
            elsif due_date >= start_of_month && due_date <= end_of_month
              due_this_month << { client: immunization_client, antigens: due_antigens }
            end
          end
        end
      end
    end

    # Update missed doses for under-five and over-five groups
    def update_missed_doses(missed_antigens, birthdate, under_five_missed_doses, over_five_missed_doses)
      missed_antigens.each do |antigen|
        missed_dose = { drug_id: antigen[:drug_id], drug_name: antigen[:drug_name], missed_doses: 1 }

        if age_in_years(birthdate) < 5
          update_dose_list(under_five_missed_doses, missed_dose)
        else
          update_dose_list(over_five_missed_doses, missed_dose)
        end
      end
    end

    # Update dose list, incrementing missed doses count if already present
    def update_dose_list(dose_list, missed_dose)
      existing_dose = dose_list.find { |dose| dose[:drug_id] == missed_dose[:drug_id] }
      if existing_dose
        existing_dose[:missed_doses] += 1
      else
        dose_list << missed_dose
      end
    end

    # Calculate age in years based on birthdate
    def age_in_years(birthdate)
      today = Date.today
      age = today.year - birthdate.year
      age -= 1 if today.month < birthdate.month || (today.month == birthdate.month && today.day < birthdate.day)
      age
    end

    # Find patient by ID
    def find_patient(patient_id)
      Person.find(patient_id)
    end

    def calculate_due_date(birthdate, age_string)
      return birthdate if age_string.downcase == 'at birth'

      age_parts = age_string.split(' ')
      number = age_parts[0].to_i
      unit = age_parts[1]

      case unit
      when 'days', 'day'
        birthdate + number
      when 'weeks', 'week'
        birthdate + (number * 7)
      when 'months', 'month'
        birthdate >> number
      when 'years', 'year'
        birthdate >> (number * 12)
      else
        birthdate
      end
    end
  end
end
