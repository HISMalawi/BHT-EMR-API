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
          base_query = Order.joins(:encounter,)
                            .merge(treatment_encounter)
          base_query.where(start_date: start_date..end_date)
                    .or(base_query.where(auto_expire_date: start_date..end_date))
                    .or(base_query.where('start_date < ? AND auto_expire_date > ?', start_date, end_date))
                    
        end

        def treatment_encounter
          Encounter.where(encounter_type: EncounterType.find_by_name('IMMUNIZATION RECORD'),
                          program_id: 33)
        end
      end
    end
  end
end
