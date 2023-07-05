# frozen_string_literal: true

class UpdatePatientIdsOnOrdersForMergedPatients < ActiveRecord::Migration[5.2]
  def up
    hanging_orders.each do |order|
      puts "Merging unmerged order ##{order['order_id']} into patient ##{order['encounter_patient_id']}..."
      ActiveRecord::Base.connection.execute <<~SQL
        UPDATE orders
        SET patient_id = #{order['encounter_patient_id']}
        WHERE orders.order_id = #{order['order_id']}
      SQL
    end
  end

  def down; end

  private

  ##
  # Returns all orders that have a different patient from that on their encounters and
  # the patient is voided.
  #
  # These orders exist due to a bug in the original NART application. When merging
  # patients, everything was merged except orders.
  def hanging_orders
    puts 'Fetching unmerged orders... Please wait...'
    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT orders.order_id,
             encounter.encounter_id,
             orders.patient_id AS order_patient_id,
             encounter.patient_id AS encounter_patient_id
      FROM orders
      INNER JOIN patient AS order_patient
        ON order_patient.patient_id = orders.patient_id
        AND order_patient.voided = 1 /* Patient on the order must be merged */
      INNER JOIN encounter USING (encounter_id)
      WHERE encounter.patient_id != orders.patient_id
    SQL
  end
end
