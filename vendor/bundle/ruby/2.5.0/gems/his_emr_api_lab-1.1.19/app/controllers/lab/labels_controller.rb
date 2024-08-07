# frozen_string_literal: true

module Lab
  class LabelsController < ApplicationController
    skip_before_action :authenticate

    def print_order_label
      order_id = params.require(:order_id)

      label = LabellingService::OrderLabel.new(order_id)
      send_data(label.print, type: 'application/label; charset=utf-8',
                             stream: false,
                             filename: "#{SecureRandom.hex(24)}.lbl",
                             disposition: 'inline')
    end
  end
end
