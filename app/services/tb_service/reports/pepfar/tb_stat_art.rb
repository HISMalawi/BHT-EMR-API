module TbService
    module Reports
        module Pepfar
            class TbStatArt
                include ArtService::Reports::Pepfar::Utils
 
                attr_reader :start_date, :end_date, :report
 
                def initialize(start_date, end_date)
                    @start_date = start_date.to_date
                    @end_date = end_date.to_date
                    @report = report_struct
                end
 
                def indicators
                    {
                        known_positive: [],
                        newly_tested_positive: [],
                        new_negative: [],
                        recent_negative: [],
                        not_done: [],
                        new_on_art: [],
                        already_on_art: []
                    }
                end
 
                def report_struct
                    pepfar_age_groups.each_with_object({}) do |age_group, hash|
                        hash[age_group] = %i[M F].each_with_object({}) do |gender, r|
                            r[gender] = indicators
                        end
                    end
                end
 
                def find_report
                    before_tb = concept('Started ARV before TB treatment').concept_id
                    while_tb = concept('Started ARV while on TB treatment').concept_id
 
 
                   query.each do |row|
                        age_group = row['age_group']
                        gender = row['gender']
                        hiv_status = row['hiv_status']
                        arv_status = row['arv_status']
                        hiv_test_date = row['hiv_test_date']
                        enrollment_date = row['enrollment_date']
                        time_of_arv_test = row['time_of_arv_test']
                        negative = concept('Negative').concept_id
                        positive = concept('Positive').concept_id
 
                        @report[age_group][gender.to_sym][:known_positive] << row['patient_id'] if hiv_status == positive && arv_status == before_tb
                        @report[age_group][gender.to_sym][:newly_tested_positive] << row['patient_id'] if hiv_status == positive && arv_status == while_tb
                        @report[age_group][gender.to_sym][:new_negative] << row['patient_id'] if hiv_status == negative && arv_status == hiv_test_date&.to_date >= enrollment_date.to_date rescue false
                        @report[age_group][gender.to_sym][:recent_negative] << row['patient_id'] if hiv_status == negative && arv_status == hiv_test_date&.to_date < 2.weeks.ago rescue false
                        @report[age_group][gender.to_sym][:not_done] << row['patient_id'] if hiv_status == nil
                        @report[age_group][gender.to_sym][:new_on_art] << row['patient_id'] if hiv_status == positive && time_of_arv_test&.to_date >= start_date && time_of_arv_test&.to_date <= end_date rescue false
                        @report[age_group][gender.to_sym][:already_on_art] << row['patient_id'] if hiv_status == positive && time_of_arv_test&.to_date < end_date rescue false
                   end
 
                   @report
                end
 
                def query
                    new_cases = new_patients_query.ref(start_date, end_date)
                    relapses = relapse_patients_query.ref(start_date, end_date)
                    patients = (new_cases + relapses)&.map(&:patient_id)
 
                    hiv_status = concept('HIV Status').concept_id
                    negative = concept('Negative').concept_id
                    positive = concept('Positive').concept_id
                    arv_status = concept('ARV status').concept_id
                    tb_program = program('TB Program').program_id
                    art_start_date = concept('ART start date').concept_id
                    time_of_arv_test = concept('HIV test period').concept_id
                   
                    ActiveRecord::Base.connection.select_all <<~SQL
                        SELECT p.patient_id, disaggregated_age_group(pe.birthdate, DATE('#{end_date}')) AS age_group,
                               pe.gender, hiv_test.value_coded AS hiv_status, hiv_test.obs_datetime AS hiv_test_date, arv_status.value_coded AS arv_status, arv_start_date.value_datetime AS arv_start_date,
                               pp.date_enrolled AS enrollment_date, time_of_arv_test.value_datetime AS time_of_arv_test
                        FROM patient p
                        INNER JOIN person pe ON pe.person_id = p.patient_id
                            AND p.voided = 0
                            AND pe.voided = 0
                            AND p.patient_id IN (#{patients.push(0).join(',')})
                        INNER JOIN patient_program pp ON pp.patient_id = p.patient_id
                            AND pp.voided = 0
                            AND pp.date_enrolled <= DATE('#{end_date}')
                        LEFT JOIN obs hiv_test ON hiv_test.person_id = p.patient_id
                            AND hiv_test.voided = 0
                            AND hiv_test.concept_id = #{hiv_status}
                        LEFT JOIN obs arv_status ON arv_status.person_id = p.patient_id
                            AND arv_status.voided = 0
                            AND arv_status.concept_id = #{arv_status}
                        LEFT JOIN obs arv_start_date ON arv_start_date.person_id = p.patient_id
                            AND arv_start_date.voided = 0
                            AND arv_start_date.concept_id = #{art_start_date}
                        LEFT JOIN obs time_of_arv_test ON time_of_arv_test.person_id = p.patient_id
                            AND time_of_arv_test.voided = 0
                            AND time_of_arv_test.concept_id = #{time_of_arv_test}
                        WHERE pp.program_id = #{tb_program}
                        GROUP BY p.patient_id
                    SQL
                end
 
                def new_patients_query
                    TbService::TbQueries::NewPatientsQuery.new
                end
 
                def relapse_patients_query
                    TbService::TbQueries::RelapsePatientsQuery.new
                end
            end
        end
    end
end