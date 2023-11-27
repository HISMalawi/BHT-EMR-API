# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      # This class is used to generate the TPT Status report for an ART patient
      class TptStatus
        attr_reader :start_date, :end_date, :patient_id

        include Utils

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date
          @end_date = end_date
          @patient_id = kwargs[:patient_id]
        end

        def find_report
          patient_tpt_status
        end

        private

        def patient_tpt_status
          return tb_treatment_status if patient_on_tb_treatment?(patient_id)
          return completed_tpt_status if patient_history_on_completed_tpt

          patient = TbPrev3.new(start_date: start_date, end_date: end_date).fetch_individual_report(patient_id)
          return default_status if patient.blank?

          tpt_status_based_on_patient(patient)
        end

        def tb_treatment_status
          {
            tpt: nil,
            completed: false,
            tb_treatment: true,
            tpt_init_date: nil,
            tpt_complete_date: nil,
            eligible: {
              '3HP': false,
              '6H': false
            }
          }
        end

        def completed_tpt_status
          tpt = patient_history_on_completed_tpt.include?('IPT') ? '6H' : '3HP'
          { tpt: tpt, completed: true, tb_treatment: false, tpt_init_date: nil, tpt_complete_date: nil, tpt_end_date: nil,
            eligible: {
              '3HP': false,
              '6H': false
            } }
        end

        def default_status
          patient = Patient.find(patient_id)
          art_start_date = patient.art_start_date
          { tpt: nil, completed: false, tb_treatment: false, tpt_init_date: nil, tpt_complete_date: nil, tpt_end_date: nil,
            eligible: {
              '3HP': end_date - art_start_date <= 3.months,
              '6H': end_date - art_start_date <= 6.months
            } }
        end

        def tpt_status_based_on_patient(patient)
          tpt = patient_on_3hp?(patient) ? '3HP' : '6H'
          completed = patient_has_totally_completed_tpt?(patient, tpt)
          tpt_init_date = patient['tpt_initiation_date']
          tpt_complete_date = completed ? patient['auto_expire_date']&.to_date : nil
          tpt_end_date = tpt == '6H' ? tpt_init_date + 6.months : tpt_init_date + 3.months
          tpt_name = if tpt == '6H'
                       'IPT'
                     else
                       (patient['drug_concepts'].split(',').length > 1 ? '3HP (RFP + INH)' : 'INH 300 / RFP 300 (3HP)')
                     end

          { tpt: tpt_name, completed: completed, tb_treatment: false,
            tpt_init_date: tpt_init_date, tpt_complete_date: tpt_complete_date,
            tpt_end_date: tpt_end_date,
            eligible: {
              '3HP': tpt == '3HP',
              '6H': tpt == '6H'
            } }
        end

        def patient_has_totally_completed_tpt?(patient, tpt)
          if tpt == '3HP'
            init_date = patient['tpt_initiation_date'].to_date
            end_date = patient['auto_expire_date'].to_date
            days_on_medication = (end_date - init_date).to_i
            days_on_medication >= 80
          else
            patient['total_days_on_medication'].to_i >= 176
          end
        end

        def patient_history_on_completed_tpt
          @patient_history_on_completed_tpt ||= Observation.where(person_id: patient_id,
                                                                  concept_id: ConceptName.find_by_name('Previous TB treatment history').concept_id)
                                                           .where("value_text LIKE '%Completed%' AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY")&.first&.value_text
        end
      end
    end
  end
end
