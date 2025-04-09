module ArtService
    module Reports
    module Clinic
        class HtnEnrollment < CachedReport

            attr_reader :start_date, :end_date, :dsd
            
             def initialize(start_date:, end_date:, **kwargs)
                super(start_date:, end_date:, definition: 'moh', **kwargs)
                @start_date = ActiveRecord::Base.connection.quote(start_date)
                @end_date = ActiveRecord::Base.connection.quote(end_date)
                @dsd = kwargs[:dsd]
            end

            PERIODS = {
                cummulative: [],
                reporting_period: []
            }

            def report_struct
                {
                    htn_enrollment: enrollment_struct,
                    treatment_drug_classification: treatment_drug_classification_struct
                }
            end


            def find_report
                patients = all_patients_diagnosed_with_htn

                cummulative = patients.each_with_object(report_struct || []) do |patient, report|
                    process_enrollement_data(patient, report, :cummulative)
                    process_treatment_drug_classification(patient, report, :cummulative)
                end

                reporting_period_patients = patients.filter do |p|
                    date_diagonised = p['date_diagonised']&.to_date
                    date_diagonised.present? && (date_diagonised >= start_date.to_date)
                end

                reporting_period_patients.each_with_object(cummulative) do |patient, report|
                    process_enrollement_data(patient, report, 'reporting_period')
                    process_treatment_drug_classification(patient, report, 'reporting_period')
                end
            end

            def process_enrollement_data(patient, report, period)
                key = :htn_enrollment
                patient_id = patient['patient_id']
                date_screened = patient['date_screened']
                date_diagonised = patient['date_diagonised']&.to_date
                lts_visit_date = patient['lts_visit_date']&.to_date
                lts_systolic = patient['lts_systolic']
                lts_diastolic = patient['lts_diastolic']
                moh_cum_outcome = patient['moh_cum_outcome']
                moh_outcome_date = patient['moh_outcome_date']&.to_date

                report[key][:registered_with_hypertension][period] << patient_id

                # Only HTN enrolled patients
                return report unless date_diagonised.present?

                report[key][:enrolled_and_active_in_care][period] << patient_id if moh_cum_outcome == 'On antiretrovirals' && date_diagonised.present?
                report[key][:who_have_defaulted_during_the_reporting_period][period] << patient_id if moh_cum_outcome == 'Defaulted'
                report[key][:who_have_died][period] << patient_id if moh_cum_outcome == 'Patient died'
                report[key][:who_have_transferred_out][period] << patient_id if moh_cum_outcome == 'Transferred out'
                report[key][:who_have_stopped_htn_care][period] << patient_id if moh_cum_outcome == 'Treatment stopped'
                report[key][:with_a_visit_in_last_3_months][period] << patient_id if lts_visit_date.present? && lts_visit_date >= (start_date.to_date - 3.months.ago.to_date)
                report[key][:with_a_visit_in_last_3_months_who_have_a_bp_measurement_recorded][period] << patient_id if lts_visit_date.present? && lts_visit_date >= (start_date.to_date - 3.months.ago.to_date) && lts_systolic.present? && lts_diastolic.present?
                report[key][:with_a_visit_in_last_3_months_who_have_bp_below_140_90][period] << patient_id if lts_visit_date.present? && lts_visit_date >= (start_date.to_date - 3.months.ago.to_date) && lts_systolic.present? && lts_diastolic.present? && lts_systolic < 140 && lts_diastolic < 90

                report
            end

            def process_treatment_drug_classification(patient, report, period)

                key = :treatment_drug_classification

                # Only HTN enrolled patients
                return report unless patient['date_diagonised']&.present?

                patient_id = patient['patient_id']
                drugs = patient['drugs']&.split(',')&.map(&:downcase) || []

                drug_category_mapping.each do |category, drugs_list|
                    report[key][category][period] << patient_id if drugs_list.any? { |drug| drugs.include?(drug) }
                end
            end

            def enrollment_struct
                {
                    registered_with_hypertension: [],
                    enrolled_and_active_in_care: [],
                    who_have_defaulted_during_the_reporting_period: [],
                    who_have_died: [],
                    who_have_transferred_out: [],
                    who_have_stopped_htn_care: [],
                    with_a_visit_in_last_3_months: [],
                    with_a_visit_in_last_3_months_who_have_a_bp_measurement_recorded: [],
                    with_a_visit_in_last_3_months_who_have_bp_below_140_90: []
                }.transform_values { |v| PERIODS }
            end

            def treatment_drug_classification_struct
               {
                    diuretics: [],
                    beta_blockers: [],
                    calcium_channel_blockers: [],
                    ace_inhibitors: [],
                    angiotensin2_receptor_blockers: [],
                    vasodilator: [],
                    others: []
                }.transform_values { |v| PERIODS }
            end


            def drug_category_mapping
                {
                    diuretics: %w[htcz frusemide spironolactone bendrofluazide],
                    beta_blockers: %w[atenolol carvedilol propranolol bisoprolol],
                    calcium_channel_blockers: %w[amlodipine nifedipine],
                    ace_inhibitors: %w[enalapril captopril lisinopril perindopril],
                    angiotensin_2_receptor_blockers: %w[losartan valsartan olmesartan telmisartan],
                    vasodilator: %w[hydralazine],
                    others: %w[]
                }
            end

            def all_patients_diagnosed_with_htn        
                ActiveRecord::Base.connection.select_all <<~SQL
                        SELECT p.patient_id,
                            DATE(vitals.encounter_datetime) AS date_screened,
                            DATE(diagnosed.date_diagonised) AS date_diagonised,
                            treatment.drugs,
                            lts_visit.lts_visit_date,
                            lts_visit.lts_systolic,
                            lts_visit.lts_diastolic,
                            tpo.moh_cum_outcome,
                            tpo.moh_outcome_date
                        FROM patient p
                        INNER JOIN encounter vitals ON vitals.patient_id = p.patient_id
                            AND vitals.voided = 0
                            AND vitals.encounter_type = #{encounter_type("VITALS").id}
                        INNER JOIN obs systolic ON systolic.encounter_id = vitals.encounter_id
                            AND systolic.voided = 0
                            AND systolic.concept_id = #{concept("Systolic blood pressure").id}
                        INNER JOIN obs diastolic ON diastolic.encounter_id = vitals.encounter_id
                            AND diastolic.voided = 0
                            AND diastolic.concept_id = #{concept("Diastolic blood pressure").id}
                        LEFT JOIN (
                            SELECT p.patient_id, date_diagnosied.value_datetime AS date_diagonised
                            FROM patient p
                            INNER JOIN encounter e ON e.patient_id = p.patient_id
                                AND e.voided = 0
                                AND e.encounter_type = #{encounter_type("HIV CLINIC CONSULTATION").id}
                            INNER JOIN obs date_diagnosied ON date_diagnosied.encounter_id = e.encounter_id
                                AND date_diagnosied.voided = 0
                                AND date_diagnosied.concept_id = #{concept("Hypertension diagnosis date").id}
                        ) diagnosed ON diagnosed.patient_id = p.patient_id
                        LEFT JOIN (
                            SELECT e.patient_id, 
                                   encounter_datetime,
                                   GROUP_CONCAT(DISTINCT c.name) AS drugs
                            FROM encounter e
                            INNER JOIN orders o ON o.encounter_id = e.encounter_id
                            INNER JOIN concept_name c ON c.concept_id = o.concept_id
                            WHERE e.voided = 0
                                AND e.encounter_type = #{encounter_type("TREATMENT").id}
                                AND o.voided = 0
                                AND e.program_id = #{program("HIV Program").id}
                            AND DATE(e.encounter_datetime) > #{start_date}
                            AND DATE(e.encounter_datetime) < #{end_date}
                            GROUP BY patient_id
                        ) treatment ON treatment.patient_id = p.patient_id
                          AND DATE(treatment.encounter_datetime) >= diagnosed.date_diagonised
                        LEFT JOIN (
                            SELECT e.patient_id,
                                    MAX(DATE(e.encounter_datetime)) AS lts_visit_date,
                                    lts_systolic.value_numeric AS lts_systolic,
                                    lts_diastolic.value_numeric AS lts_diastolic
                            FROM encounter e
                                LEFT JOIN obs lts_systolic ON lts_systolic.encounter_id = e.encounter_id
                                    AND lts_systolic.voided = 0
                                    AND lts_systolic.concept_id = #{concept("Systolic blood pressure").id}
                                LEFT JOIN obs lts_diastolic ON lts_diastolic.encounter_id = e.encounter_id
                                    AND lts_diastolic.voided = 0
                                    AND lts_diastolic.concept_id = #{concept("Diastolic blood pressure").id}
                            WHERE e.voided = 0
                            AND e.encounter_type = #{encounter_type("VITALS").id}
                            AND e.program_id = #{program("HIV Program").id}
                            GROUP BY patient_id
                        ) AS lts_visit ON lts_visit.patient_id = p.patient_id
                        LEFT JOIN temp_patient_outcomes tpo ON tpo.patient_id = p.patient_id
                        WHERE vitals.program_id = #{program("HIV Program").id}
                        AND DATE(vitals.encounter_datetime) <= #{end_date}
                        GROUP BY patient_id
                SQL
            end
        end
        end
    end
end