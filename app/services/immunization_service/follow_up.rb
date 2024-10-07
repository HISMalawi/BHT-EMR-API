require 'date'

module ImmunizationService
  class FollowUp
    
    # Immunization program ID
    IMMUNIZATION_PROGRAM_ID = 33

    def initialize
    end

    # Fetch all missed immunizations or milestones 
    def fetch_missed_immunizations(location_id)
      immunization_clients = fetch_immunization_clients(location_id)
      today = Date.today
      start_of_week = today.beginning_of_week
      end_of_week = today.end_of_week
      start_of_month = today.beginning_of_month
      end_of_month = today.end_of_month

      due_today_antigens = {}
      due_this_week_antigens = {}
      due_this_month_antigens = {}
      overdue_antigens = {}

      under_five_missed_visits = []
      over_five_missed_visits = []
      under_five_count = 0
      over_five_count = 0
      under_five_missed_doses = []
      over_five_missed_doses = []

      immunization_clients.each do |patient_id, birthdate, given_name, family_name,city_village|
        immunization_client = OpenStruct.new(patient_id:, birthdate:, given_name:, family_name:, city_village:)
        client_missed_visits = []
        vaccine_schedules = ImmunizationService::VaccineScheduleService.vaccine_schedule(find_patient(patient_id))

        process_vaccine_schedules(vaccine_schedules, client_missed_visits, under_five_missed_doses,
                                  over_five_missed_doses, today, start_of_week, end_of_week,
                                  start_of_month, end_of_month, immunization_client,
                                  due_today_antigens, due_this_week_antigens, due_this_month_antigens,
                                  overdue_antigens)

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
        under_five_missed_visits:,
        over_five_missed_visits:,
        under_five_count:,
        over_five_count:,
        under_five_missed_doses:,
        over_five_missed_doses:,
        due_today_count: due_today_antigens.values.flat_map { |antigen| antigen[:clients] }.uniq.count,
        due_this_week_count: due_this_week_antigens.values.flat_map { |antigen| antigen[:clients] }.uniq.count,
        due_this_month_count: due_this_month_antigens.values.flat_map { |antigen| antigen[:clients] }.uniq.count,
        due_today_antigens: due_today_antigens.values,
        due_this_week_antigens: due_this_week_antigens.values,
        due_this_month_antigens: due_this_month_antigens.values,
        overdue_antigens: overdue_antigens.values
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
      Patient.joins(:encounters, person: [:names, :addresses])
             .where('encounter.program_id = ? AND encounter.location_id = ?', IMMUNIZATION_PROGRAM_ID, location_id)
             .distinct
             .pluck('patient.patient_id, person.birthdate, person_name.given_name, person_name.family_name,person_address.city_village')
    end

    # Process vaccine schedules and determine missed doses
    def process_vaccine_schedules(vaccine_schedules, client_missed_visits, under_five_missed_doses,
      over_five_missed_doses, today, start_of_week, end_of_week, start_of_month, end_of_month, immunization_client,
      due_today_antigens, due_this_week_antigens, due_this_month_antigens, overdue_antigens)

      vaccine_schedules.each do |vaccine_schedule|
        vaccine_schedule[1].each do |visit|

          missed_antigens = visit[:antigens].select do |antigen|
            antigen[:can_administer] && antigen[:status] == 'pending' && visit[:milestone_status] == 'passed'
          end

          if missed_antigens.any?
            client_missed_visits << { visit: visit[:visit], milestone_status: visit[:milestone_status],
                                      age: visit[:age], antigens: missed_antigens
                                    }
            update_missed_doses(missed_antigens, under_five_missed_doses, over_five_missed_doses, immunization_client )
            
            # Add missed antigens to overdue_antigens
            missed_antigens.each do |antigen|
              (overdue_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
            end
          end

          due_antigens = visit[:antigens].select do |antigen|
            antigen[:can_administer] && antigen[:status] == 'pending' && visit[:milestone_status] == 'current'
          end

          next if due_antigens.empty? # No need to execute below code if no antigens are due

          due_date = calculate_due_date(immunization_client.birthdate, visit[:age])

          if due_date == today
            # Appending due today antigens
            due_antigens.each do |antigen|
              (due_today_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
              (due_this_week_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
              (due_this_month_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
            end
          elsif due_date >= start_of_week && due_date <= end_of_week
            # Appending due this week antigens
            due_antigens.each do |antigen|
              (due_this_week_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
              (due_this_month_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
            end
          elsif due_date >= start_of_month && due_date <= end_of_month
            # Appending due this month antigens
            due_antigens.each do |antigen|
              (due_this_month_antigens[antigen[:drug_id]] ||= { drug_name: antigen[:drug_name], clients: [] })[:clients] << immunization_client
            end
          end
        end
      end
    end

    # Update missed doses for under-five and over-five groups
    def update_missed_doses(missed_antigens, under_five_missed_doses, over_five_missed_doses, immunization_client)
      missed_antigens.each do |antigen|
        missed_dose = { drug_id: antigen[:drug_id], drug_name: antigen[:drug_name], missed_doses: 1, clients: [immunization_client]}

        if age_in_years(immunization_client.birthdate) < 5
          update_dose_list(under_five_missed_doses, missed_dose, immunization_client)
        else
          update_dose_list(over_five_missed_doses, missed_dose, immunization_client)
        end
      end
    end

    # Update dose list, incrementing missed doses count if already present
    def update_dose_list(dose_list, missed_dose, immunization_client)
      existing_dose = dose_list.find { |dose| dose[:drug_id] == missed_dose[:drug_id] }
      if existing_dose
        existing_dose[:missed_doses] += 1
        existing_dose[:clients] << immunization_client unless existing_dose[:clients].include?(immunization_client)
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
      # If the age string is "at birth", return the birthdate as the due date
      return birthdate if age_string.downcase == 'at birth'
      
      # Split the age string into a number and a unit (e.g., "2 months" -> ["2", "months"])
      age_parts = age_string.split(' ')
      
      # Convert the number part of the age string to an integer
      number = age_parts[0].to_i
      
      # Get the unit of time (e.g., "days", "weeks", "months", "years") and make it lowercase
      unit = age_parts[1].downcase
      
      # Calculate the due date by adding the appropriate amount of time to the birthdate
      case unit
      when 'days', 'day'
        birthdate + number.days   # Add the specified number of days to the birthdate
      when 'weeks', 'week'
        birthdate + number.weeks  # Add the specified number of weeks to the birthdate
      when 'months', 'month'
        birthdate + number.months # Add the specified number of months to the birthdate
      when 'years', 'year'
        birthdate + number.years  # Add the specified number of years to the birthdate
      else
        birthdate  # If the unit is not recognized, return the birthdate unchanged
      end
    end
    
    # Counts the antigens due
    def aggregate_antigens(antigens)
      antigen_count = Hash.new {  |hash, key| hash[key] = { drug_name: key, due_count: 0 }}

      antigens.each do |antigen|
        antigen_count[antigen[:drug_id]][:due_count] += 1
        antigen_count[antigen[:drug_id]][:drug_name] = antigen[:drug_name]
      end

      antigen_count.values
    end
  end
end
