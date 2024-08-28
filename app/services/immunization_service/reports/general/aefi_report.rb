# frozen_string_literal: true

module ImmunizationService
  module Reports
    module General
      class AefiReport
        attr_reader :start_date, :end_date, :location_id, :age_group
      
        def initialize(params)
          set_attributes(params)
        end
      
        def data
          find_report()
        end
      
        private
      
        def set_attributes(params)
          @start_date = parse_date(params[:start_date], :beginning_of_day)
          @end_date = parse_date(params[:end_date], :end_of_day)
          @location_id = params[:location_id]
          @age_group = parse_age_group(params[:age_group])
        end
      
        def parse_date(date_string, time_of_day)
          date_string ? Date.parse(date_string).send(time_of_day) : Date.today.send(time_of_day)
        end
      
        def parse_age_group(age_group_string)
          age_group_string ? JSON.parse(age_group_string) : ['all']
        rescue JSON::ParserError
          ['all']
        end
      
        def find_report
          generate(@start_date, @end_date)
        end
      
        def generate(start_date, end_date)
          end_date ||= start_date
          vaccine_adverse_effects_concept_id = ConceptName.find_by_name('Vaccine adverse effects').concept_id
          
          vaccine_adverse_effects = Observation.joins(:encounter)
                              .merge(immunization_followup_encounter)
                              .joins("LEFT JOIN (
                                SELECT concept_id, MIN(name) AS name
                                FROM concept_name
                                WHERE voided = 0
                                GROUP BY concept_id
                              ) AS unique_concept_name ON obs.value_coded = unique_concept_name.concept_id")
                              .select("obs.*, unique_concept_name.name AS value_coded_name")
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
              person_id: nil,
              concept_id: nil,
              concept_name: nil,
              drugs: []
            }
            data[:person_id] = ob.person_id
            data[:concept_id] = ob.value_coded
            data[:concept_name] = ob.value_coded_name
          
            if ob.children
              ob.children.each do |ob_child|
                if ob_child.value_coded
                  data[:drugs] << { drug_inventory_id: ob_child.value_coded }
                end
              end
            end
            
            result << data if data[:drugs].any?
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
