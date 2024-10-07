# frozen_string_literal: true

module ImmunizationService
  module Reports
    module General
      class VaccinesAdministered
        include ModelUtils
        attr_reader :start_date, :end_date, :age_group
        require 'date'

        def initialize(start_date: nil, end_date: nil, location_id: nil, **kwargs)
          @start_date = start_date ? Date.parse(start_date).beginning_of_day : Date.today.beginning_of_day
          @end_date = end_date ? Date.parse(end_date).end_of_day : Date.today.end_of_day
          @location_id = location_id
          @age_group = kwargs[:age_group] ? JSON.parse(kwargs[:age_group]) : ['all']
        end

        def data
          find_report()
        end

        private

        def find_report
          generate(@start_date, @end_date)
        end
        
        def calculate_age(birthdate, reference_date)
          return nil if birthdate.nil? || reference_date.nil?
          
          birthdate = Date.parse(birthdate) if birthdate.is_a?(String)
          reference_date = Date.parse(reference_date) if reference_date.is_a?(String)
          
          reference_date.year - birthdate.year - ((reference_date.month > birthdate.month || (reference_date.month == birthdate.month && reference_date.day >= birthdate.day)) ? 0 : 1)
        rescue Date::Error
          nil
        end
        
        def generate(start_date, end_date)
          batch_number_concept_id = ConceptName.find_by_name('Batch Number').concept_id

          base_query = Order.joins(:encounter)
                            .joins("LEFT JOIN obs ON obs.encounter_id = encounter.encounter_id")
                            .joins(patient: :person, drug_order: :drug)
                            .joins("LEFT JOIN person_address ON person.person_id = person_address.person_id")
                            .joins("LEFT JOIN person_name ON  person.person_id = person_name.person_id")
                            .merge(vaccine_encounter)
                            .where("obs.location_id = ?", @location_id)
                            .where("obs.concept_id != ?", batch_number_concept_id)
                            .where("obs.voided = ?", 0)
                            .where.not(obs: { value_text: ['Unknown', nil, ''] })
                            .select('orders.*, drug_order.*, drug.*', 'person.*', 'obs.*', 'person_address.*', 'person_name.*')
        
          orders = base_query.where(start_date: start_date..end_date)
                             .or(base_query.where(auto_expire_date: start_date..end_date))
                             .or(base_query.where('orders.start_date < ? AND orders.auto_expire_date > ?', start_date, end_date))
        
          less_than_one_year = []
          greater_than_one_year = []
        
          orders.each do |order|
            birthdate = order.birthdate
            order_date = order.start_date
        
            age = calculate_age(birthdate, order_date)
        
            relevant_data = {
              order_id: order.order_id,
              patient_id: order.patient_id,
              given_name: order.given_name,
              family_name: order.family_name,
              drug_name: order.name,
              drug_inventory_id: order.drug_inventory_id,
              start_date: order.start_date,
              age_at_order: age,
              gender: order.gender,
              city_village: order.city_village,
              state_province: order.state_province,
              township_division: order.township_division,
              changed_by: order.changed_by,
              birthdate: order.birthdate,
              birthdate_estimated: order.birthdate_estimated,
              date_created: order.date_created,
              creator: order.creator,
              value_text: order.value_text
            }
        
            if age.nil?
              # Handle cases where age couldn't be calculated
              puts "Warning: Could not calculate age for order #{order.order_id}"
            elsif age < 1
              less_than_one_year << relevant_data
            else
              greater_than_one_year << relevant_data
            end
          end
        
          {
            less_than_one_year: less_than_one_year,
            greater_than_one_year: greater_than_one_year
          }
        end

        def vaccine_encounter
          program = Program.find_by name: "IMMUNIZATION PROGRAM"
          Encounter.where(encounter_type: EncounterType.find_by_name('TREATMENT'),
                          program_id: program.program_id)
        end
      end
    end
  end
end
