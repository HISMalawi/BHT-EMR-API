module Api
  module V1
    class AuditsController < ApplicationController
      def index
        @audits = Audit.all
        filters.each do |k, v|
          @audits = @audits.where(k => v) if Audit.column_names.include? k
        end

        start_date, end_date, audit_action = filters[:start_date], filters[:end_date], filters[:audit_action]

        if start_date && end_date
          @audits = @audits.where(created_at: start_date&.to_date&.beginning_of_day..end_date&.to_date&.end_of_day)
        end

        @audits = @audits.where(action: filters[:audit_action]) if audit_action

        render json: @audits
      end

      def filters
        params.permit %i[auditable_type audit_action user_id start_date end_date]
      end
    end
  end
end