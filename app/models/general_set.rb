# frozen_string_literal: true

class GeneralSet < ApplicationRecord
  self.table_name = :dset
  self.primary_key = :set_id

  has_many :drug_sets, -> { where voided: 0 }, foreign_key: :set_id # , optional: true

  def activate(date)
    return unless status != 'active'

    update_attribute('status', 'active')
    update_attribute('date_updated', date) unless date.blank?
  end

  def deactivate(date)
    return unless status != 'inactive'

    update_attribute('status', 'inactive')
    update_attribute('date_updated', date) unless date.blank?
  end

  def block(date)
    return unless status != 'blocked'

    update_attribute('status', 'blocked')
    update_attribute('date_updated', date) unless date.blank?
  end
end
