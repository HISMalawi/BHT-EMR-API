# rubocop:disable Metrics/MethodLength, Style/Documentation, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
# frozen_string_literal: true

module OpdService
  module Reports
    class OpdDisaggregated
      attr_accessor :start_date, :end_date, :report

      include ModelUtils
      include ArtService::Reports::Pepfar::Utils

      def find_report(start_date:, end_date:, **_extra_kwargs)
        @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
        @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        @report = {
          data: fmt,
          aggregated:
        }

        process
      end

      def fmt
        pepfar_age_groups.each_with_object({}) do |age_group, r|
          r[age_group] = %w[M F].each_with_object({}) do |g, gr|
            gr[g] = {
              total: [],
              prev_pos_not_on_art: [],
              prev_pos_on_art: [],
              prev_neg: [],
              new_neg: [],
              new_pos: [],
              not_done: [],
              screened: [],
              not_screened: []
            }
          end
        end
      end

      def aggregated
        {
          p: [],
          bf: [],
          fnp: [],
          all_female: [],
          all_male: []
        }
      end

      def process
        breastfeeding_concepts = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                            .select(:concept_id).map(&:concept_id).join(',')

        patients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT disaggregated_age_group(pe.birthdate, '#{end_date}') AS age_group,
            CASE
              WHEN pe.gender = 'Male' THEN 'M'
              WHEN pe.gender = 'Female' THEN 'F'
              ELSE pe.gender
            END gender,
            p.patient_id,
            reg_date.encounter_datetime registration_date,
            hiv_obs.hiv_status,
            hiv_obs.test_date,
            hiv_obs.date_started_art,
            hiv_obs.started_art,
            screened.person_id screened_for_tb,
            preg_status.pregnant,
            preg_status.breastfeeding
              FROM encounter e
              INNER JOIN person pe ON pe.person_id = e.patient_id
                  AND pe.voided = 0
              INNER JOIN patient p ON p.patient_id = e.patient_id
                  AND p.voided = 0
              INNER JOIN encounter reg_date ON reg_date.patient_id = e.patient_id
                  AND reg_date.encounter_type = #{EncounterType.find_by_name('PATIENT REGISTRATION').encounter_type_id}
                  AND reg_date.voided = 0
              LEFT JOIN (
                SELECT e.patient_id,
                       hiv_status.value_text hiv_status,
                       tst_date.value_datetime test_date,
                       started_art.value_coded started_art,
                       date_started_art.value_datetime date_started_art
                FROM encounter e
                INNER JOIN obs hiv_status ON hiv_status.encounter_id = e.encounter_id
                  AND hiv_status.voided = 0
                  AND hiv_status.concept_id = #{concept('HIV Status').concept_id}
                INNER JOIN obs tst_date ON tst_date.encounter_id = e.encounter_id
                    AND tst_date.concept_id = #{concept('HIV test date').concept_id}
                    AND tst_date.voided = 0
                LEFT JOIN obs started_art ON started_art.encounter_id = e.encounter_id
                    AND started_art.concept_id = #{concept('ART started').concept_id}
                    AND started_art.voided = 0
                LEFT JOIN obs date_started_art ON date_started_art.encounter_id = e.encounter_id
                  AND date_started_art.concept_id = #{concept('Date antiretrovirals started').concept_id}
                  AND date_started_art.voided = 0
                  AND e.encounter_datetime >= '#{start_date}' AND e.encounter_datetime <= '#{end_date}'
              ) AS hiv_obs ON hiv_obs.patient_id = p.patient_id
              LEFT JOIN (
                SELECT obs.person_id#{' '}
                FROM obs
                  WHERE obs.voided = 0
                  AND obs.concept_id = #{concept('Routine TB Screening').concept_id}
                  AND obs.obs_datetime >= '#{start_date}' AND obs.obs_datetime <= '#{end_date}'
              ) AS screened ON screened.person_id = e.patient_id
              LEFT JOIN (
                SELECT brest.value_coded as breastfeeding,
                       brest.person_id,
                       preg.value_coded as pregnant
                FROM obs brest
                LEFT JOIN obs preg ON preg.encounter_id = brest.encounter_id
                AND preg.concept_id = #{concept('Pregnant?').concept_id}
                AND brest.obs_datetime >= '#{start_date}' AND brest.obs_datetime <= '#{end_date}'
                WHERE brest.concept_id IN (#{breastfeeding_concepts})
                AND brest.voided = 0
                AND preg.voided = 0
                AND brest.obs_datetime >= '#{start_date}' AND brest.obs_datetime <= '#{end_date}'
              ) AS preg_status ON preg_status.person_id = p.patient_id
            WHERE e.program_id = #{Program.find_by_name('OPD program').program_id}
            AND reg_date.encounter_datetime >= '#{start_date}' AND reg_date.encounter_datetime <= '#{end_date}'
            AND e.voided = 0
            GROUP BY e.patient_id
        SQL

        process_results(patients)
      end

      def process_results(patients)
        yes_concept = concept('Yes').concept_id

        patients.each do |p|
          patient_id = p['patient_id']
          age_group = p['age_group']
          gender = p['gender']
          hiv_status = p['hiv_status']&.downcase || nil
          date_started_art = p['date_started_art']&.to_date || nil
          opd_reg_date = p['registration_date']&.to_date
          started_art = p['started_art']
          screened_for_tb = p['screened_for_tb'] || nil
          pregnant = p['pregnant']
          bf = p['breastfeeding']

          report[:data][age_group][gender][:total] << patient_id

          report[:data][age_group][gender][screened_for_tb.nil? ? :not_screened : :screened] << patient_id

          if gender == 'F'
            report[:aggregated][:all_female] << patient_id
            report[:aggregated][:p] << patient_id if pregnant == yes_concept
            report[:aggregated][:bf] << patient_id if bf == yes_concept
            report[:aggregated][:fnp] << patient_id unless [pregnant, bf].include?(yes_concept)
          else
            report[:aggregated][:all_male] << patient_id
          end

          unless hiv_status.nil?
            if hiv_status == 'reactive'
              if date_started_art <= opd_reg_date
                report[:data][age_group][gender][:new_pos] << patient_id
              elsif date_started_art > opd_reg_date && started_art == concept('No').concept_id
                report[:data][age_group][gender][:prev_pos_not_on_art] << patient_id
              elsif date_started_art > opd_reg_date && started_art == concept('Yes').concept_id
                report[:data][age_group][gender][:prev_pos_on_art] << patient_id
              end
            elsif hiv_status == 'non-reactive' && date_started_art > opd_reg_date
              report[:data][age_group][gender][:new_neg] << patient_id
            elsif hiv_status == 'non-reactive' && date_started_art <= opd_reg_date
              report[:data][age_group][gender][:prev_neg] << patient_id
            elsif hiv_status == 'unknown'
              report[:data][age_group][gender][:not_done] << patient_id
            end
          end
          report[:data][age_group][gender][:not_done] << patient_id if [nil, 'unknown'].any?(hiv_status)
        end

        report
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength, Style/Documentation, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
