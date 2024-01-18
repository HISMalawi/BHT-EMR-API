# frozen_string_literal: true

class GeneralSet < ApplicationRecord
  self.table_name = :dset
  self.primary_key = :set_id

  has_many :drug_sets, -> { where voided: 0 }, foreign_key: :set_id # , optional: true

  def activate(date)
    return unless status != 'active'

    update_attributes(status: 'active')
    update_attributes(date_updated: date) unless date.blank?
  end

  def deactivate(date)
    return unless status != 'inactive'

    update_attributes(status: 'inactive')
    update_attributes(date_updated: date) unless date.blank?
  end

  def block(date)
    return unless status != 'blocked'

    update_attributes(status: 'blocked')
    update_attributes(date_updated: date) unless date.blank?
  end
end
