class EmrOhspInterface::EmrOhspInterfaceController < ::ApplicationController
    def weeks_generator
        render json: service.weeks_generator();
    end   

    def months_generator
        render json: service.months_generator();
    end  

    def generate_weekly_idsr_report
        render json: service.generate_weekly_idsr_report(params[:request],params[:start_date],params[:end_date]);
    end 
    
    def generate_monthly_idsr_report
        render json: service.generate_monthly_idsr_report(params[:request],params[:start_date],params[:end_date]);
    end

    def generate_hmis_15_report
        render json: service.generate_hmis_15_report(params[:start_date],params[:end_date]);
    end

    def generate_hmis_17_report
        render json: service.generate_hmis_17_report(params[:start_date],params[:end_date]);
    end
   
    def service
        EmrOhspInterface::EmrOhspInterfaceService
    end
end