# frozen_string_literal: true

module Lab
  class LimsOrderMapping < ApplicationRecord
    belongs_to :order, class_name: 'LabOrder', foreign_key: 'order_id'

    validates_presence_of :lims_id, :order_id
    validates_uniqueness_of :lims_id, :order_id
  end
end
