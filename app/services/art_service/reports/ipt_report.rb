# frozen_string_literal: true

module ARTService
  module Reports

    class IPTReport
      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def ipt_coverage
        return coverage
      end


      private 

      def coverage
        program_id = Program.find_by_name('HIV program').id
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id FROM encounter
        WHERE encounter_type = #{EncounterType.find_by_name('HIV Reception').id}
        AND encounter_datetime BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
        AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}' AND voided = 0
        AND program_id = #{program_id}
        GROUP BY DATE(encounter_datetime), patient_id;
EOF

        patient_ids = data.map{|p| p['patient_id'].to_i}
        return {patients: 0, prescribed: 0, dispensed: 0} if patient_ids.blank?

        ipt_drugs = Drug.where('name LIKE (?)', "%Isoniazid%").map(&:drug_id)

        data = ActiveRecord::Base.connection.select_one <<EOF
        SELECT count(o.patient_id) AS prescribed FROM orders o
        INNER JOIN encounter e ON e.encounter_id = o.encounter_id
        INNER JOIN drug_order i ON i.order_id = o.order_id
        WHERE o.voided = 0 AND e.patient_id IN(#{patient_ids.join(',')})
        AND start_date BETWEEN "#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}"
        AND "#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}" 
        AND drug_inventory_id IN(#{ipt_drugs.join(',')}) 
        AND e.program_id = #{program_id};
EOF
    
=begin    
        data = Order.where("start_date BETWEEN ? AND ? AND drug_inventory_id IN(?)
          AND program_id = ? AND orders.patient_id IN(?)", 
          @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          @end_date.to_date.strftime('%Y-%m-%d 23:59:59'), ipt_drugs, program_id, patient_ids).\
          joins("INNER JOIN encounter e ON e.encounter_id = orders.encounter_id
          INNER JOIN drug_order i ON i.order_id = orders.order_id").count(:patient_id)
=end

        data2 = ActiveRecord::Base.connection.select_one <<EOF
        SELECT count(o.patient_id) AS dispensed FROM orders o
        INNER JOIN encounter e ON e.encounter_id = o.encounter_id
        INNER JOIN drug_order i ON i.order_id = o.order_id
        WHERE o.voided = 0 AND e.patient_id IN(#{patient_ids.join(',')})
        AND start_date BETWEEN "#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}"
        AND "#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}"
        AND drug_inventory_id IN(#{ipt_drugs.join(',')})
        AND quantity > 0 AND e.program_id = #{program_id};
EOF
   

        prescribed = data['prescribed']
        dispensed  = data2['dispensed']
        return {patients: patient_ids.length, prescribed: prescribed, dispensed: dispensed}
      end


    end
  end

end
