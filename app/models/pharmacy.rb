# frozen_string_literal: true

class Pharmacy < VoidableRecord
  self.table_name = :pharmacy_obs
  self.primary_key = :pharmacy_module_id

  # def self.total_removed(drug_id, start_date = Date.today, end_date = Date.today)
  #   pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins removed')

  #   begin
  #     active.find(:first, select: 'SUM(value_numeric) total_removed',
  #                         conditions: ["pharmacy_encounter_type = ? AND drug_id = ?
  #                           AND encounter_date >= ? AND encounter_date <= ?",
  #                                      pharmacy_encounter_type.id, drug_id, start_date, end_date],
  #                         group: 'drug_id').total_removed.to_f
  #   rescue StandardError
  #     0
  #   end
  # end

  # def self.drug_dispensed_stock_adjustment(drug_id, quantity, encounter_date, reason = nil)
  #   encounter_type = PharmacyEncounterType.find_by_name('Tins removed').id if encounter_type.blank?
  #   encounter = new
  #   encounter.pharmacy_encounter_type = encounter_type
  #   encounter.drug_id = drug_id
  #   encounter.encounter_date = encounter_date
  #   encounter.value_numeric = quantity.to_f
  #   encounter.value_text = reason unless reason.blank?
  #   encounter.save
  # end

  # def self.date_ranges(date)
  #   current_range = []
  #   current_range << Report.cohort_range(date).last
  #   end_date = Report.cohort_range(Date.today).last
  #   while current_range.last < end_date
  #     current_range << Report.cohort_range(current_range.last + 1.day).last
  #   end
  #   begin
  #     current_range[1..-1]
  #   rescue StandardError
  #     nil
  #   end
  # end

  # def self.dispensed_drugs_since(drug_id, start_date = Date.today, end_date = Date.today)
  #   return 0 if start_date.blank? || end_date.blank?
  #   dispensed_encounter = EncounterType.find_by_name('DISPENSING')
  #   amount_dispensed_concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
  #   start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
  #   end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')

  #   begin
  #     Encounter.find(:first, joins: 'INNER JOIN obs USING(encounter_id)',
  #                            select: 'SUM(value_numeric) total_dispensed',
  #                            conditions: ["concept_id = ? AND encounter_type = ?
  #                        AND obs_datetime >= ? AND obs_datetime <= ? AND value_drug = ?",
  #                                         amount_dispensed_concept_id, dispensed_encounter.id,
  #                                         start_date, end_date, drug_id],
  #                            group: 'value_drug').total_dispensed.to_f
  #   rescue StandardError
  #     0
  #   end
  # end

  # def self.dispensed_drugs_to_date(drug_id)
  #   dispensed_encounter = EncounterType.find_by_name('DISPENSING')
  #   amount_dispensed_concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id

  #   begin
  #     Encounter.find(:first, joins: 'INNER JOIN obs USING(encounter_id)',
  #                            select: 'SUM(value_numeric) total_dispensed',
  #                            conditions: ['concept_id = ? AND encounter_type = ? AND value_drug = ?',
  #                                         amount_dispensed_concept_id, dispensed_encounter.id, drug_id],
  #                            group: 'value_drug').total_dispensed.to_f
  #   rescue StandardError
  #     0
  #   end
  # end

  # def self.current_stock(drug_id)
  #   current_stock_as_from(drug_id, first_delivery_date(drug_id), Date.today)
  # end

  # def self.current_stock_as_from(drug_id, start_date = Date.today, end_date = Date.today)
  #   total_delivered = self.total_delivered(drug_id, start_date, end_date)
  #   total_dispensed = dispensed_drugs_since(drug_id, start_date, end_date)
  #   total_removed = self.total_removed(drug_id, start_date, end_date)
  #   (total_delivered - (total_dispensed + total_removed))
  # end

  # def self.new_delivery(drug_id, pills, date = Date.today, encounter_type = nil, expiry_date = nil)
  #   encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id if encounter_type.blank?
  #   delivery = new
  #   delivery.pharmacy_encounter_type = encounter_type
  #   delivery.drug_id = drug_id
  #   delivery.encounter_date = date
  #   delivery.expiry_date = expiry_date unless expiry_date.blank?
  #   delivery.value_numeric = pills.to_f

  #   if expiry_date
  #     if expiry_date.to_date < Date.today
  #       delivery.voided = 1
  #       return delivery.save
  #     end
  #   end
  #   delivery.save
  # end

  # def self.total_delivered(drug_id, start_date = Date.today, end_date = Date.today)
  #   pharmacy_encounter_type = PharmacyEncounterType.find_by_name('New deliveries')

  #   begin
  #     active.find(:first, select: 'SUM(value_numeric) total_delivered',
  #                         conditions: ["pharmacy_encounter_type = ? AND drug_id = ?
  #                           AND encounter_date >= ? AND encounter_date <= ?",
  #                                      pharmacy_encounter_type.id, drug_id, start_date, end_date],
  #                         group: 'drug_id').total_delivered.to_f
  #   rescue StandardError
  #     0
  #   end
  # end

  # def self.first_delivery_date(drug_id)
  #   encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id
  #   begin
  #     Pharmacy.active.find(:first, conditions: ['drug_id=? AND pharmacy_encounter_type=?', drug_id, encounter_type],
  #                                  order: 'encounter_date ASC,date_created ASC').encounter_date
  #   rescue StandardError
  #     nil
  #   end
  # end

  # def self.expiring_drugs(start_date, end_date)
  #   pharmacy_encounter_type = PharmacyEncounterType.find_by_name('New deliveries')

  #   expiring_drugs = active.find(:all,
  #                                conditions: ["pharmacy_encounter_type = ?
  #                                AND expiry_date >= ? AND expiry_date <= ?",
  #                                             pharmacy_encounter_type.id, start_date, end_date])

  #   expiring_drugs_hash = {}
  #   (expiring_drugs || []).each do |expiring|
  #     current_stock = current_stock_as_from(expiring.drug_id, first_delivery_date(expiring.drug_id), end_date)
  #     next if current_stock <= 0
  #     expiring_drugs_hash["#{expiring.pharmacy_module_id}:#{Drug.find(expiring.drug_id).name}"] = {
  #       'delivered_stock' => expiring.value_numeric,
  #       'date_delivered' => expiring.encounter_date,
  #       'expiry_date' => expiring.expiry_date,
  #       'current_stock' => current_stock
  #     }
  #   end
  #   expiring_drugs_hash
  # end

  # def self.removed_from_shelves(start_date, end_date)
  #   pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins removed')

  #   removed_from_shelves = active.find(:all,
  #                                      conditions: ["pharmacy_encounter_type = ?
  #                                      AND encounter_date >= ? AND encounter_date <= ?",
  #                                                   pharmacy_encounter_type.id, start_date, end_date])

  #   removed_from_shelves_hash = {}
  #   (removed_from_shelves || []).each do |removed|
  #     current_stock = current_stock_as_from(removed.drug_id, first_delivery_date(removed.drug_id), end_date)
  #     removed_from_shelves_hash["#{removed.pharmacy_module_id}:#{Drug.find(removed.drug_id).name}"] = {
  #       'amount_removed' => removed.value_numeric,
  #       'date_removed' => removed.encounter_date,
  #       'reason' => removed.value_text,
  #       'current_stock' => current_stock
  #     }
  #   end
  #   removed_from_shelves_hash
  # end

  # def self.prescribed_drugs_since(drug_id, start_date, end_date = Date.today)
  #   treatment_encounter_type = EncounterType.find_by_name('TREATMENT')
  #   drug_orders = DrugOrder.find(:all,
  #                                joins: "INNER JOIN orders ON drug_order.order_id = orders.order_id
  #                                INNER JOIN encounter e ON e.encounter_id = orders.encounter_id",
  #                                conditions: ["encounter_type = ? AND drug_inventory_id = ?
  #                                AND encounter_datetime >= ? AND encounter_datetime <= ?",
  #                                             treatment_encounter_type.id, drug_id,
  #                                             start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
  #                                             end_date.to_date.strftime('%Y-%m-%d 23:59:59')])

  #   return 0 if drug_orders.blank?
  #   prescribed_drugs = 0
  #   drug_orders.each do |drug_order|
  #     prescribed_drugs += (drug_order.duration * drug_order.equivalent_daily_dose)
  #   end
  #   prescribed_drugs
  # end
end
