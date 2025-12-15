module Api
    module V1
        class FacilitiesController < ApplicationController
            before_action :set_facility, only: [:show, :update, :destroy]
        
            # GET /facilities
            def index
                service = FacilityService.new(search_params)
                if search_params[:district_name].present?
                # Filter facilities by district_name
                result = service.list_facilities_by_district(search_params[:district_name])
                else
                # Default behavior
                result = service.list_facilities
                end
            
                render json: {
                facilities: serialize_facilities(result[:facilities]),
                total: result[:total],
                filters_applied: result[:filters_applied]
                }
            end
  

            # GET /districts
            def districts
                service = FacilityService.new
                districts = service.list_districts
            
                render json: {
                districts: districts,
                total: districts.count
                }
            end
        
            # GET /facilities/:id
            def show
            render json: serialize_facility(@facility)
            end
        
            # GET /facilities/:id/nearby
            def nearby
            service = FacilityService.new(search_params)
            result = service.find_nearby_facilities(params[:id])
        
            render json: {
                facilities: serialize_facilities(result[:facilities]),
                total: result[:total],
                center_facility: serialize_facility(result[:center_facility])
            }
            end
        
            # POST /facilities
            def create
            service = FacilityService.new
            facility = service.create_facility(facility_params)
            
            render json: serialize_facility(facility), status: :created
            rescue ActiveRecord::RecordInvalid => e
            render json: { errors: e.record.errors }, status: :unprocessable_entity
            end
        
            # PATCH/PUT /facilities/:id
            def update
            service = FacilityService.new
            facility = service.update_facility(params[:id], facility_params)
            
            render json: serialize_facility(facility)
            rescue ActiveRecord::RecordInvalid => e
            render json: { errors: e.record.errors }, status: :unprocessable_entity
            end
        
            # DELETE /facilities/:id
            def destroy
            service = FacilityService.new
            service.delete_facility(params[:id])
            
            head :no_content
            rescue ActiveRecord::RecordNotFound
            render json: { error: 'Facility not found' }, status: :not_found
            end
        
            private
        
            def set_facility
                @facility = Facility.find_by('id = ? OR code = ?', params[:id], params[:id])
                
                if @facility.nil?
                  render json: { error: 'Facility not found' }, status: :not_found
                end
            end
        
            def facility_params
            params.require(:facility).permit(
                :code,
                :name,
                :common,
                :facility_type,
                :status,
                :district,
                :latitude,
                :longitude
            )
            end
        
            def search_params
            params.permit(
                :name,
                :district,
                :district_name,
                :status,
                :latitude,
                :longitude,
                :radius,
                :sort_by
            )
            end
        
            def serialize_facility(facility)
                # the custom 'as_json' logic in the Location model.
                facility.as_json(
                    include: {
                    location_attributes: {
                        only: %i[location_attribute_id attribute_type_id value_reference]
                    }
                    }
                )
            end
                    
            def serialize_facilities(facilities)
                facilities.map { |facility| serialize_facility(facility) }
            end
        end
    end
end