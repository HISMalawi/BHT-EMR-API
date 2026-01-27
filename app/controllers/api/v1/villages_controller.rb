# frozen_string_literal: true

module Api
  module V1
    class VillagesController < ApplicationController
      def create
        params = params.require(%i[name traditional_authority_id])

        village = Village.create(params)
        if village.errors.empty?
          render json: village, status: :created
        else
          render json: village.errors, status: :bad_request
        end
      end

      def index
        filters = params.permit(%i[traditional_authority_id village_id name])

        traditional_authority_id, name, village_id = filters.values_at(:traditional_authority_id, :name, :village_id)
        villages = Village.all

        if traditional_authority_id
          villages = villages.where(parent_location: traditional_authority_id)
        end

        if name
          villages = villages.where('name like ?', "%#{name}%")
        end

        if village_id
          villages = villages.where(location_id: village_id)
        end

        render json: paginate(villages.order(:name))
      end

      def show
        village = Village.includes(:traditional_authority).find_by(village_id: params[:id])
        
        if village
          render json: village.as_json(include: :traditional_authority)
        else
          render json: { error: 'Village not found' }, status: :not_found
        end
      end
      def destroy
        trad_auth = Village.find(params[:id])
        trad_auth.destroy!
      
        render json: { message: "Village successfully deleted" }, status: :ok
        rescue ActiveRecord::RecordNotDestroyed => e
          render json: { error: e.message }, status: :unprocessable_entity
      end
      def update()
        village = Village.find(params[:id])
        village.update!(
          name: params[:name] || village.name,
          traditional_authority_id: params[:ta_id] || village.traditional_authority_id,
          date_created: Time.current,
          creator: User.current.id
        )
        render json: { data:village.reload}
      end
    end
  end
end
