# frozen_string_literal: true

class DrugOrder < ApplicationRecord
  self.table_name = :drug_order
  self.primary_key = :order_id

  belongs_to :drug, foreign_key: :drug_inventory_id
  belongs_to :order, foreign_key: :order_id

  validates_presence_of :drug_inventory_id, :equivalent_daily_dose

  def as_json(options = {})
    super(options.merge(
      include: { order: {}, drug: {} }, methods: %i[dosage_struct amount_needed barcodes regimen]
    ))
  end

  def regimen
    return unless order.encounter.program_id == 1 # HIV Program
    return unless drug.arv?

    regimen = ActiveRecord::Base.connection.select_one("SELECT patient_current_regimen(#{order.patient_id}, DATE('#{order.start_date.to_date}')) regimen")
    regimen['regimen']
  end

  def barcodes
    drug.barcodes
  end

  def duration
    order = self.order || Order.unscoped.find_by_order_id(order_id)
    return 0 if order&.auto_expire_date.blank? || order&.start_date.blank?

    interval = (order.discontinued_date.blank? ? order.auto_expire_date.to_date : order.discontinued_date.to_date) - order.start_date.to_date
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
    value = if weekly_dose?
              (((duration * (equivalent_daily_dose || 1)) - (quantity || 0)) / 7)
            else
              (duration * (equivalent_daily_dose || 1)) - (quantity || 0)
            end

    value.negative? ? 0 : value.ceil
  end

  def total_required
    (duration * equivalent_daily_dose)
  end

  # Construct
  def dosage_struct
    ingredient = MohRegimenIngredient.find_by(drug:)
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
    begin
      return order.instructions unless order.instructions.blank?
    rescue StandardError
      nil
    end

    str = "#{drug.name}: #{dose} #{units} #{frequency} for #{duration || 'some'} days"
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
end
