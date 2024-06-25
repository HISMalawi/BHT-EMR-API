class ImmunizationReportChannel < ApplicationCable::Channel

    def subscribed
        stream_from "immunization_report"
    end

    def unsubscribed
        # Any cleanup needed when channel is unsubscribed
    end 

    def fetch_data(data)
        start_date = data['start_date']
        end_date = data['end_date']
        ImmunizationReportJob.perform_later(start_date, end_date)
    end


end 