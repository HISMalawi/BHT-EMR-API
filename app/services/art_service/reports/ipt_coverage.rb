# frozen_string_literal: true

module ArtService
  module Reports
    # Cohort report builder class.
    #
    # This class only provides one public method (start_build_report) besides
    # the constructor. This method must be called to build report and save
    # it to database.
    class IptCoverage
      def initialize(start_date:, end_date:)
        @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
        @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
      end

      def data
        patient_ids = []
        patients = {}

        (on_art_in_reporting_period || []).each do |data|
          patient_ids << data['patient_id'].to_i
        end

        return patients if patient_ids.blank?

        data = ipt_dispensations(patient_ids)

        (data || []).each do |record|
          patient_id = record['patient_id'].to_i
          age_group = record['age_group']
          gender = record['gender']

          gender = if gender.blank?
                     'Unknown'
                   else
                     (gender.match(/F/i) ? 'Female' : 'Male')
                   end

          patients[age_group] = {} if patients[age_group].blank?
          patients[age_group][gender] = {} if patients[age_group][gender].blank?
          patients[age_group][gender][patient_id] = 0 if patients[age_group][gender][patient_id].blank?

          prescription_info = ActiveRecord::Base.connection.select_one <<-SQL
            SELECT TIMESTAMPDIFF(day, DATE('#{record['start_date']}'), DATE('#{record['auto_expire_date']}')) days;
          SQL

          next if prescription_info['days'].blank?

          patients[age_group][gender][patient_id] += prescription_info['days'].to_i
        end

        age_groups = {}

        (patients || {}).each do |keys, values|
          pats = values
          (pats || {}).each do |sex, ids|
            (ids || {}).each do |patient_id, count|
              next unless count >= 168

              age_groups[keys] = {} if age_groups[keys].blank?
              age_groups[keys][sex] = [] if age_groups[keys][sex].blank?
              age_groups[keys][sex] << patient_id
            end
          end
        end

        age_groups
      end

      private

      def on_art_in_reporting_period
        ActiveRecord::Base.connection.select_all <<-SQL
          select
            `p`.`patient_id` AS `patient_id`, pe.birthdate, pe.gender,
             cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`
          from
            ((`patient_program` `p`
            left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
            left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
            left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
          where
            ((`p`.`voided` = 0)
                and (`s`.`voided` = 0)
                and (`p`.`program_id` = 1)
                and (`s`.`state` = 7))
                /*and (DATE(`s`.`start_date`) BETWEEN '#{@start_date}' AND '#{@end_date}')*/
                and pepfar_patient_outcome(p.patient_id, DATE('#{@end_date}')) = 'On antiretrovirals'
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL;
        SQL
      end

      def ipt_dispensations(patient_ids)
        date_six_months_ago = (@start_date.to_date - 6.months).strftime('%Y-%m-%d 00:00:00')

        ActiveRecord::Base.connection.select_all <<-SQL
          SELECT
              o.patient_id, birthdate, gender, o.start_date, o.auto_expire_date,
              disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) age_group
          FROM person p
          INNER JOIN orders o ON o.patient_id = p.person_id
          INNER JOIN drug_order t ON o.order_id = t.order_id
          INNER JOIN drug d ON d.drug_id = t.drug_inventory_id
          WHERE o.voided = 0 AND (o.start_date BETWEEN '#{date_six_months_ago}' AND '#{@end_date}')
          AND d.concept_id = 656 AND o.patient_id IN(#{patient_ids.join(',')})
          AND t.quantity > 0 ORDER BY o.patient_id;
        SQL
      end
    end
  end
end
