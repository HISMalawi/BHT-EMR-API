class Api::V1::ImmunizationReportController < ApplicationController

    def stats
        start_date = params[:start_date]
        end_date = params[:end_date]

        if start_date.blank? || end_date.blank?
            render json: { error: 'Start Date and end date are required'}, 
                status: :unprocessable_entity
        end

        dashboard = ImmunizationService::Reports::Stats::ImmunizationDashboard.new(
            start_date: start_date,
            end_date: end_date
        )

        render json: dashboard.data

    end
end