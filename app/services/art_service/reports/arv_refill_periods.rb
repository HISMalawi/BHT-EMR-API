# frozen_string_literal: true

module ARTService
  module Reports

    class ArvRefillPeriods
      def initialize(start_date:, end_date:, min_age:, max_age:)
        @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
        @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        @min_age = min_age
        @max_age = max_age
      end

      def arv_refill_periods
        return break_down
      end

      private 
      
      def break_down
        program_id = Program.find_by(name: 'HIV PROGRAM').id
        arv_concept_set = ConceptName.find_by(name: 'ARVS').concept_id
        encounter_type = EncounterType.find_by(name: 'DISPENSING').id
        
        if @min_age == 'Unknown' && @max_age == 'Unknown'
          sql_path = "AND pe.birthdate IS NULL"
          sql_path += " AND patient_outcome(p.patient_id, DATE('#{@end_date}')) = 'On antiretrovirals'"
        else
          sql_path = "AND TIMESTAMPDIFF(year, pe.birthdate, DATE('#{@end_date}')) BETWEEN #{@min_age} AND #{@max_age}"
          sql_path += " AND patient_outcome(p.patient_id, DATE('#{@end_date}')) = 'On antiretrovirals'"
        end

        concept_id = ConceptName.find_by_name('Type of patient').concept_id
        ext_concept_id = ConceptName.find_by_name('External consultation').concept_id

        person_ids = Observation.where(concept_id: concept_id,
          value_coded: ext_concept_id).group(:person_id).map(&:person_id)
        person_ids = [0] if person_ids.blank?

        patients = ActiveRecord::Base.connection.select_all <<EOF
        select
            `p`.`patient_id` AS `patient_id`,
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
                and (DATE(`s`.`start_date`) <= '#{@end_date}')
                #{sql_path} AND p.patient_id NOT IN(#{person_ids.join(',')})
          group by `p`.`patient_id`
          HAVING date_enrolled IS NOT NULL;
EOF

        return {} if patients.blank?
        patient_ids = patients.map{|p|p['patient_id'].to_i}

        data = ActiveRecord::Base.connection.select_all <<EOF
          SELECT 
            o.patient_id, p.gender, p.birthdate, o.start_date, o.auto_expire_date, d.name, od.quantity,
            TIMESTAMPDIFF(month, DATE(o.start_date), DATE(o.auto_expire_date)) prescribed_months
          FROM orders o 
          INNER JOIN drug_order od ON od.order_id = o.order_id
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
          INNER JOIN concept_set s ON s.concept_id = d.concept_id
          INNER JOIN person p ON p.person_id = o.patient_id
          INNER JOIN encounter e ON e.patient_id = p.person_id
          WHERE s.concept_set = #{arv_concept_set} AND o.voided = 0
          AND DATE(o.start_date) = (
            SELECT DATE(MAX(o.start_date)) FROM orders t WHERE t.patient_id = o.patient_id
            AND t.voided = 0 AND t.start_date <= '#{@end_date}'
          ) AND e.program_id = #{program_id} AND o.patient_id IN(#{patient_ids.join(',')})
          AND od.quantity > 0 AND e.encounter_type = #{encounter_type} 
          GROUP BY o.patient_id, d.drug_id;
EOF

        results = {}
        (data || []).each do |info|
          patient_id = info['patient_id'].to_i
          prescribed_months = info['prescribed_months'].to_i
          med = info['name']
          gender = info['gender']
          birthdate = info['birthdate']

          results[patient_id] = {
            drug: med, prescribed_months: prescribed_months, 
            birthdate: birthdate, gender: gender
          } if results[patient_id].blank?

          if prescribed_months > results[patient_id][:prescribed_months]
            results[patient_id][:drug] = med
            results[patient_id][:prescribed_months] = prescribed_months
          end

        end

        return results
      end

    
    end
  end
end
