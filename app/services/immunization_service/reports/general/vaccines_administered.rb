# frozen_string_literal: true

module ImmunizationService
  module Reports
    module General
      class VaccinesAdministered
        include ModelUtils
        attr_reader :start_date, :end_date, :age_group

        def initialize(start_date: nil, end_date: nil, **kwargs)
          @start_date = start_date ? Date.parse(start_date).beginning_of_day : Date.today.beginning_of_day
          @end_date = end_date ? Date.parse(end_date).end_of_day : Date.today.end_of_day
          @age_group = kwargs[:age_group] ? JSON.parse(kwargs[:age_group]) : ['all']
        end

        def data
          find_report()
        end

        private

        def find_report
          generate(@start_date, @end_date)
        end
  
        def generate(start_date, end_date)
          base_query = Order.joins(:encounter, patient: :person, drug_order: :drug,)
                            .merge(vaccine_encounter)
                            .select('orders.*, drug_order.*, drug.*', 'person.*')
        
          base_query.where(start_date: start_date..end_date)
                    .or(base_query.where(auto_expire_date: start_date..end_date))
                    .or(base_query.where('orders.start_date < ? AND orders.auto_expire_date > ?', start_date, end_date))
        end

        def vaccine_encounter
          program = Program.find_by name: "IMMUNIZATION PROGRAM"
          Encounter.where(encounter_type: EncounterType.find_by_name('IMMUNIZATION RECORD'),
                          program_id: program.program_id)
        end
      end
    end
  end
end
