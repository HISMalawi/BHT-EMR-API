# frozen_string_literal: true

module Lab
  module Lims
    module Api
      ##
      # A LIMS Api wrappper that does nothing really.
      #
      # Primarily meant as a dummy for testing environments.
      class BlackholeApi
        def create_order(order_dto); end

        def update_order(order_dto); end

        def void_order(order_dto); end

        def consume_orders(&); end
      end
    end
  end
end
