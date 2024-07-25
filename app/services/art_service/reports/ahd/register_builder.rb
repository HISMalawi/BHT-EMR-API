# frozen_string_literal: true

include ModelUtils

module ArtService
  module Reports
    module Ahd
      # Generates a discrepancy report for a clinic
      class RegisterBuilder
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, relation: Patient.all)
          @start_date = start_date.to_date&.beginning_of_day
          @end_date = end_date.to_date&.end_of_day
          @relation = relation.extending(Scopes)
          @hiv_program = Program.find_by(name: 'HIV Program')
        end

        def register
          ahd_encounter = EncounterType.find_by_name('SYMPTOM SCREENING')

          @relation.joins(encounters: [:observations])
                   .where(encounter: { program_id: @hiv_program.id })
                   .where(encounter: { encounter_datetime: start_date...end_date })
                   .where(encounter: { encounter_type: ahd_encounter.encounter_type_id })
                   .group('patient.patient_id')
                   .select('patient.patient_id')
        end

        module Scopes
          def genders
            select('person.gender AS gender')
              .merge(female_breastfeeding)
              .merge(female_pregnant)
          end

          def ahd_outcomes
            select("pepfar_patient_outcome(patient.patient_id, '#{Date.today}') AS outcome")
          end

          def ahd_lab_orders
            test_types = [
              'HIV Viral load',
              'CD4 count',
              'CrAg',
              'CSF CrAg',
              'Urine LAM',
              'GeneXpert',
              'FASH'
            ]

            test_type_ids = test_types.map { |type| concept(type).concept_id }

            select('tt.name, GROUP_CONCAT(DISTINCT CONCAT(result.value_modifier, ",",
                             COALESCE(result.value_numeric, result.value_text, result.value_coded))) AS test_results')
              .joins <<~SQL
                LEFT JOIN orders ON orders.patient_id = encounter.patient_id
                AND orders.voided = 0
                LEFT JOIN obs test_type ON test_type.order_id = orders.order_id
                AND test_type.concept_id = #{concept('Test type').concept_id}
                AND test_type.value_coded IN (#{test_type_ids.join(', ')})
                INNER JOIN concept_name tt ON tt.concept_id = test_type.value_coded
                LEFT JOIN obs tr ON tr.order_id = orders.order_id
                AND tr.voided = 0
                AND tr.concept_id = 7363
                AND tr.obs_group_id = test_type.obs_id
                INNER JOIN obs result ON result.obs_group_id = tr.obs_id
              SQL
          end

          def who_stage
            who_stage = concept('WHO stage').concept_id

            select('COALESCE(stage.value_coded, "Unknown") AS who_stage')
              .joins <<~SQL
                LEFT JOIN obs stage ON stage.person_id = encounter.patient_id
                AND stage.concept_id = #{who_stage}
                AND stage.voided = 0
              SQL
          end

          def ahd_classification
            classification = concept('AHD entry classification').concept_id

            select('COALESCE(class.value_text, "Unknown") AS classification')
              .joins <<~SQL
                LEFT JOIN obs class ON class.person_id = encounter.patient_id
                AND class.concept_id = #{classification}
                AND class.voided = 0
              SQL
          end

          def ever_received_arvs
            received = concept('Ever received ART?').concept_id
            merge(genders)
              .select('COALESCE(arv.value_coded, "No") AS arv, current.patient_id as current')
              .joins <<~SQL
                LEFT JOIN obs arv ON arv.person_id = encounter.patient_id
                AND arv.concept_id = #{received}
                AND arv.voided = 0
                LEFT JOIN temp_cohort_members current ON current.patient_id = encounter.patient_id
                AND current.date_enrolled <= encounter.encounter_datetime
              SQL
          end

          def ahd_symptoms
            symptoms = concept('AHD Symptom').concept_id
            yes = concept('Yes').concept_id

            select('GROUP_CONCAT(DISTINCT symptom_name.name) AS symptoms')
              .joins <<~SQL
                LEFT JOIN obs symptom_obs ON obs.person_id = encounter.patient_id
                AND symptom_obs.concept_id = #{symptoms}
                AND symptom_obs.voided = 0
                INNER JOIN obs symptom ON symptom.obs_group_id = symptom_obs.obs_id
                AND symptom.value_coded = #{yes}
                AND symptom.voided = 0
                INNER JOIN concept_name symptom_name ON symptom_name.concept_id = symptom_obs.value_coded
                AND symptom_name.voided = 0
              SQL
          end

          def female_breastfeeding
            breastfeeding = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                       .pluck(:concept_id)&.join(',')
            yes = concept('Yes').concept_id

            joins(:person)
              .select('COALESCE(bf.person_id, "No") AS bf')
              .joins <<~SQL
                LEFT JOIN obs bf ON bf.person_id = encounter.patient_id
                AND bf.concept_id IN (#{breastfeeding})
                AND person.gender = "F"
                AND bf.value_coded = #{yes}
                AND bf.voided = 0
              SQL
          end

          def female_pregnant
            pregnant = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                  .pluck(:concept_id)&.join(',')
            yes = concept('Yes').concept_id

            joins(:person)
              .select('COALESCE(preg.person_id, "No") AS preg')
              .joins <<~SQL
                LEFT JOIN obs preg ON preg.person_id = encounter.patient_id
                AND person.gender = "F"
                AND preg.concept_id IN (#{pregnant})
                AND preg.value_coded = #{yes}
                AND preg.voided = 0
              SQL
          end
        end
      end
    end
  end
end
