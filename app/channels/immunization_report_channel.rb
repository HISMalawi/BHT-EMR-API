class ImmunizationReportChannel < ApplicationCable::Channel

    def subscribed
        location_id = params[:location_id]
        stream_from "immunization_report_channel_#{location_id}"
    end

    def unsubscribed
        # Any cleanup needed when channel is unsubscribed
    end 
end 