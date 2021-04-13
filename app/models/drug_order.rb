# frozen_string_literal: true

class DrugOrder < ApplicationRecord
  self.table_name = :drug_order
  self.primary_key = :order_id

  belongs_to :drug, foreign_key: :drug_inventory_id
  belongs_to :order, foreign_key: :order_id

  validates_presence_of :drug_inventory_id, :equivalent_daily_dose

  def as_json(options = {})
    super(options.merge(
      include: { order: {}, drug: {} }, methods: %i[amount_needed barcodes]
    ))
  end

  def barcodes
    drug.barcodes
  end

  def duration
    order = self.order || Order.unscoped.find_by_order_id(order_id)
    return 0 if order&.auto_expire_date.blank? || order&.start_date.blank?

    interval = order.auto_expire_date.to_date - order.start_date.to_date
    interval.to_i
  end

  # Calculates the duration which the current drugs may last
  # given the equivalent daily dose
  def quantity_duration
    duration = quantity / equivalent_daily_dose
    duration *= 7 if weekly_dose?

    duration.to_i
  end

  def amount_needed
    if weekly_dose?
      value = (((duration * (equivalent_daily_dose || 1)) - (quantity || 0)) / 7)
    else
      value = (duration * (equivalent_daily_dose || 1)) - (quantity || 0)
    end

    value.negative? ? 0 : value
  end

  def total_required
    (duration * equivalent_daily_dose)
  end

  # Construct
  def dosage_struct
    ingredient = MohRegimenIngredient.find_by(drug: drug)
    {
      drug_id: drug.drug_id,
      drug_name: drug.name,
      am: ingredient&.dose&.am || 0,
      noon: 0, # Requested by the frontenders
      pm: ingredient&.dose&.pm || 0,
      units: drug.units
    }
  end

  def to_s
    return order.instructions unless order.instructions.blank? rescue nil

    str = "#{drug.name}: #{self.dose} #{self.units} #{frequency} for #{duration||'some'} days"
    str << ' (prn)' if prn == 1
    str
  end

  def date_created
    @date_created ||= Order.unscoped.find(order_id).date_created
  end

  def weekly_dose?
    return false unless frequency

    frequency.match?(/Weekly/i)
  end

  # def order
  #   @order ||= Order.find(order_id)
  # end

  # def to_s
  #   return order.instructions unless order.instructions.blank? rescue nil
  #   s = "#{drug.name}: #{self.dose} #{self.units} #{frequency} for #{duration||'some'} days"
  #   s << " (prn)" if prn == 1
  #   s
  # end

  # def to_short_s
  #   return order.instructions unless order.instructions.blank? rescue nil
  #   s = "#{drug.name}: #{self.dose} #{self.units} #{frequency} for #{duration||'some'} days"
  #   s << " (prn)" if prn == 1
  #   s
  # end

  # def self.find_common_orders(diagnosis_concept_id)
  #   # Note we are not worried about drug.retired in this case
  #   joins = "INNER JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0
  #            INNER JOIN obs ON orders.obs_id = obs.obs_id AND obs.value_coded = #{diagnosis_concept_id} AND obs.voided = 0
  #            INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id"
  #   self.all(
  #     :joins => joins,
  #     :select => "*, MIN(drug_order.order_id) as order_id, COUNT(*) as number, CONCAT(drug.name, ':', dose, ' ', drug_order.units, ' ', frequency, ' for ', DATEDIFF(auto_expire_date, start_date), ' days', IF(prn=1, ' prn', '')) as script",
  #     :group => ['drug.name, dose, drug_order.units, frequency, prn, DATEDIFF(start_date, auto_expire_date)'],
  #     :order => "COUNT(*) DESC")
  # end

  # def self.clone_order(encounter, patient, obs, drug_order)
  #   write_order(encounter, patient, obs, drug_order.drug, Time.now,
  #     Time.now + drug_order.duration.days, drug_order.dose, drug_order.frequency,
  #     drug_order.prn, drug_order.order.instructions, drug_order.equivalent_daily_dose)
  # end

  # # Eventually it would be good for this to not be hard coded, and the data available in the concept table
  # def self.doses_per_day(frequency)
  #   return 1 if frequency == "ONCE A DAY (OD)"
  #   return 2 if frequency == "TWICE A DAY (BD)"
  #   return 3 if frequency == "THREE A DAY (TDS)"
  #   return 4 if frequency == "FOUR TIMES A DAY (QID)"
  #   return 5 if frequency == "FIVE TIMES A DAY (5X/D)"
  #   return 6 if frequency == "SIX TIMES A DAY (Q4HRS)"
  #   return 1 if frequency == "IN THE MORNING (QAM)"
  #   return 1 if frequency == "ONCE A DAY AT NOON (QNOON)"
  #   return 1 if frequency == "IN THE EVENING (QPM)"
  #   return 1 if frequency == "ONCE A DAY AT NIGHT (QHS)"
  #   return 0.5 if frequency == "EVERY OTHER DAY (QOD)"
  #   return 1.to_f / 7.to_f if frequency == "ONCE A WEEK (QWK)"
  #   return 1.to_f / 28.to_f if frequency == "ONCE A MONTH"
  #   return 1.to_f / 14.to_f if frequency == "TWICE A MONTH"
  #   1
  # end

  # # prn should be 0 | 1
  # def self.write_order(encounter, patient, obs, drug, start_date, auto_expire_date, dose, frequency, prn, instructions = nil, equivalent_daily_dose = nil)
  #   encounter ||= patient.current_treatment_encounter
  #   units = drug.units || 'per dose'
  #   duration = (auto_expire_date.to_date - start_date.to_date).to_i rescue nil
  #   equivalent_daily_dose = nil
  #   drug_order = nil
  #   if (frequency == "VARIABLE")
  #     if instructions.blank?
  #       instructions = "#{drug.name}:"
  #       instructions += " IN THE MORNING (QAM):#{dose[0]} #{units}" unless dose[0].blank? || dose[0].to_f == 0
  #       instructions += " ONCE A DAY AT NOON (QNOON):#{dose[1]} #{units}" unless dose[1].blank? || dose[1].to_f == 0
  #       instructions += " IN THE EVENING (QPM):#{dose[2]} #{units}" unless dose[2].blank? || dose[2].to_f == 0
  #       instructions += " ONCE A DAY AT NIGHT (QHS):#{dose[3]} #{units}" unless dose[3].blank? || dose[3].to_f == 0
  #       instructions += " for #{duration} days"
  #       instructions += " (prn)" if prn == 1
  #     end
  #     if dose.is_a?(Array)
  #       total_dose = dose.sum{|amount| amount.to_f rescue 0 }
  #       return nil if total_dose.blank?
  #       dose = total_dose
  #     end
  #     equivalent_daily_dose ||= dose
  #   else
  #     equivalent_daily_dose ||= dose.to_f * DrugOrder.doses_per_day(frequency)
  #     if instructions.blank?
  #       instructions = "#{drug.name}: #{dose} #{units} #{frequency} for #{duration||'some'} days"
  #       instructions += " (prn)" if prn == 1
  #     end
  #   end
  #   ActiveRecord::Base.transaction do
  #     order = encounter.orders.create(
  #       :order_type_id => 1,
  #       :concept_id => drug.concept_id,
  #       :orderer => User.current_user.user_id,
  #       :patient_id => patient.id,
  #       :start_date => start_date,
  #       :auto_expire_date => auto_expire_date,
  #       :observation => obs,
  #       :instructions => instructions)
  #     drug_order = DrugOrder.new(
  #       :drug_inventory_id => drug.id,
  #       :dose => dose,
  #       :frequency => frequency,
  #       :prn => prn,
  #       :units => units,
  #       :equivalent_daily_dose => equivalent_daily_dose)
  #     drug_order.order_id = order.id
  #     drug_order.save!
  #   end
  #   drug_order
  # end

  # # We have to recalculate everything each time, because this might be the result
  # # of a clinical worker voiding something.
  # def total_drug_supply(patient, encounter = nil, session_date = Date.today)
  #   if encounter.blank?
  #     type = EncounterType.find_by_name("DISPENSING")
  #     encounter = encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",session_date,type.id])
  #   end

  #   return [] if encounter.blank?

  #   amounts_brought = Observation.all(:conditions =>
  #     ['obs.concept_id = ? AND ' +
  #      'obs.person_id = ? AND ' +
  #      "DATE(encounter.encounter_datetime) = '#{session_date.to_date}' AND " +
  #      'drug_order.drug_inventory_id = ?',
  #       ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id,
  #       patient.person.person_id,
  #       drug_inventory_id],
  #     :include => [:encounter, [:order => :drug_order]])
  #   total_brought = amounts_brought.sum{|amount| amount.value_numeric}
  #   amounts_dispensed = Observation.all(:conditions => ['concept_id = ? AND order_id = ? AND encounter_id = ?', ConceptName.find_by_name("AMOUNT DISPENSED").concept_id, self.order_id, encounter.encounter_id])
  #   total_dispensed = amounts_dispensed.sum{|amount| amount.value_numeric}
  #   self.quantity = total_dispensed + total_brought
  #   self.save
  #   amounts_dispensed
  # end


end
