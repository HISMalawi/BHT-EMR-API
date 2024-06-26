class ImmunizationReportChannel < ApplicationCable::Channel

    def subscribed
        stream_from "immunization_report_channel"
    end

    def unsubscribed
        # Any cleanup needed when channel is unsubscribed
    end 
end 