# frozen_string_literal: true

module ImmunizationService
  module Reports
    module General
      class AefiReport
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
        
        
        def generate(start_date, end_date)
          end_date ||= start_date
          vaccine_adverse_effects_concept_id = ConceptName.find_by_name('Vaccine adverse effects').concept_id
          
          vaccine_adverse_effects = Observation.joins(:encounter)
                              .merge(immunization_followup_encounter)
                              .joins("LEFT JOIN concept_name ON obs.value_coded = concept_name.concept_id")
                              .select("obs.*, concept_name.name AS value_coded_name")
                              .where(
                                concept_id: vaccine_adverse_effects_concept_id,
                                location_id: @location_id,
                                voided: 0,
                                obs_datetime: start_date..end_date
                              )
                              .where.not(value_coded: nil)
                              .order(obs_datetime: :desc)

          result = []
          vaccine_adverse_effects.each do |ob|
            data = {
              value_coded_name: nil,
              drugs: []
            }
            data[:value_coded_name] = ob.value_coded_name
          
            if ob.children
              ob.children.each do |ob_child|
                data[:drugs] << { drug_inventory_id: ob_child.value_coded }
              end
            end

            result << data
          end
                              
          {
            data: result
          }

        end

        def immunization_followup_encounter
          program = Program.find_by name: "IMMUNIZATION PROGRAM"
          Encounter.where(encounter_type: EncounterType.find_by_name('IMMUNIZATION FOLLOWUP'),
                          program_id: program.program_id)
        end

      end
    end
  end
end
