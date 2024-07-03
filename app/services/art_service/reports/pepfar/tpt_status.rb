# frozen_string_literal: true

module ArtService
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
          @tpt_status = {}
        end

        def find_report
          patient_tpt_status
        rescue StandardError => e
          Rails.logger.error("Error generating TPT Status report for patient #{patient_id}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise e
        end

        private

        def patient_tpt_status
          return tb_treatment_status if patient_on_tb_treatment?(patient_id)
          return completed_tpt_status if patient_history_on_completed_tpt

          patient = TbPrev3.new(start_date:, end_date:).fetch_individual_report(patient_id)
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
          { tpt:, completed: true, tb_treatment: false, tpt_init_date: nil, tpt_complete_date: nil, tpt_end_date: nil,
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
              '3HP': art_start_date ? difference_in_months(end_date.to_date, art_start_date.to_date) < 3 : true,
              '6H': art_start_date ? difference_in_months(end_date.to_date, art_start_date.to_date) < 3 : true
            } }
        end

        def tpt_status_based_on_patient(patient)
          tpt = determine_tpt(patient)
          completed = patient_has_totally_completed_tpt?(patient, tpt)
          tpt_init_date = patient['tpt_initiation_date']
          tpt_current_expiry_date = patient['auto_expire_date']&.to_date
          diff_in_months = difference_in_months(end_date.to_date, tpt_current_expiry_date)
          art_start_date = Patient.find(patient_id).art_start_date
          tpt_complete_date = completed ? patient['auto_expire_date']&.to_date : nil
          tpt_end_date = calculate_tpt_end_date(tpt, tpt_init_date)
          tpt_name = determine_tpt_name(tpt, patient)
          arv_drug_runout_date = patient_arv_drug_runout_date

          @tpt_status.merge!({ tpt: tpt_name, completed:, tb_treatment: false,
                               tpt_init_date:, tpt_complete_date:,
                               tpt_end_date:, art_start_date:,
                               art_drug_auto_expire_date: arv_drug_runout_date })
          determine_eligibility(tpt, diff_in_months, art_start_date, arv_drug_runout_date)
        end

        def determine_tpt(patient)
          patient_on_3hp?(patient) ? '3HP' : '6H'
        end

        def determine_tpt_name(tpt, patient)
          if tpt == '6H'
            'IPT'
          else
            (patient['drug_concepts'].split(',').length > 1 ? '3HP (RFP + INH)' : 'INH 300 / RFP 300 (3HP)')
          end
        end

        def calculate_tpt_end_date(tpt, tpt_init_date)
          tpt == '6H' ? tpt_init_date + 6.months : tpt_init_date + 3.months
        end

        def determine_eligibility(tpt, diff_in_months, art_start_date, arv_drug_runout_date)
          three_hp_eligible = false
          six_h_eligible = false
          tpt_init_date = @tpt_status[:tpt_init_date]
          tpt_end_date = @tpt_status[:tpt_end_date]
          case tpt
          when '3HP'
            # 3HP is taken 1 dose per week
            # if client misses dose for less than a month, they are eligible
            # if client misses more than a month:
            # check if they have been on ART for less than 3 months, they are eligible
            # if they have been on ART continuosly for more than 3 months, they are not eligible
            three_hp_eligible = true if diff_in_months <= 1
            if diff_in_months > 1 &&  difference_in_months(end_date.to_date, art_start_date.to_date) < 3
              #  Patient defaulted for ART and TPT and was on ART for less than 3 months: patient TPT status is reset
              
              three_hp_eligible = true
              six_h_eligible = false
              tpt_end_date = nil
              tpt_init_date = nil
              @tpt_status.merge!({ tpt: nil })
            end
          when '6H'
            # 6H is taken 1 dose per day
            # if client misses dose for less than 2 months, they are eligible
            # if client misses more than a month:
            # check if they have been on ART for less than 3 months, they are eligible
            # if they have been on ART continuosly for more than 3 months, they are not eligible
            six_h_eligible = true if diff_in_months <= 2
            if diff_in_months > 2 && difference_in_months(end_date.to_date, art_start_date.to_date) < 3
              #  Patient defaulted for ART and TPT and was on ART for less than 3 months: patient TPT status is reset
              three_hp_eligible = false
              six_h_eligible = true
              tpt_end_date = nil
              tpt_init_date = nil
              @tpt_status.merge!({ tpt: nil })
            end
          end
          @tpt_status.merge!({
                               tpt_init_date:,
                               tpt_end_date:,
                               eligible: {
                                 '3HP': three_hp_eligible,
                                 '6H': six_h_eligible
                               }
                             })
        end

        def patient_has_totally_completed_tpt?(patient, tpt)
          if tpt == '3HP'
            init_date = patient['tpt_initiation_date'].to_date
            end_date = patient['auto_expire_date'].to_date
            if patient['drug_concepts'].split(',').length > 1
              days_on_medication = (end_date - init_date).to_i
              days_on_medication >= 84
            else
              patient['total_pills_taken'].to_i >= 36
            end
          else
            patient['total_days_on_medication'].to_i >= 182
          end
        end

        def patient_arv_drug_runout_date
          Patient.find(patient_id).last_arv_drug_expire_date
        end

        def patient_history_on_completed_tpt
          @patient_history_on_completed_tpt ||= Observation.where(person_id: patient_id,
                                                                  concept_id: ConceptName.find_by_name('Previous TB treatment history').concept_id)
                                                           .where("value_text LIKE '%complete%' AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY")&.first&.value_text
        end

        def difference_in_months(date1, date2)
          result = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH, '#{date2}', '#{date1}') months")
          result['months'].to_i
        end
      end
    end
  end
end
