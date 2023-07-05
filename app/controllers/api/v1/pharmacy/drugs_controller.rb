# frozen_string_literal: true

module Api
  module V1
    module Pharmacy
      class DrugsController < ApplicationController
        def drug_consumption
          drug_id = params.require(:drug_id)
          render json: stock_management_service.drug_consumption(drug_id)
        end

        private

        def stock_management_service
          StockManagementService.new
        end
      end
    end
  end
end
