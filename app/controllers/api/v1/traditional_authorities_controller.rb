# frozen_string_literal: true

module Api
  module V1
    class TraditionalAuthoritiesController < ApplicationController
      def create
        params = params.require(%i[name district_id])

        trad_auth = TraditionalAuthority.create(params)
        if trad_auth.errors.empty?
          render json: trad_auth, status: :created
        else
          render json: trad_auth.errors, status: :bad_request
        end
      end

      def index
        filters = params.permit(%i[district_id name traditional_authority_id])

        district_id, name, traditional_authority_id = filters.values_at(:district_id, :name, :traditional_authority_id)
        traditional_authorities = TraditionalAuthority.all

        if district_id
          traditional_authorities = traditional_authorities.where(parent_location: district_id)
        end

        if name
          traditional_authorities = traditional_authorities.where('name like ?', "%#{name}%")
        end

        if traditional_authority_id
          traditional_authorities = traditional_authorities.where(location_id: traditional_authority_id)
        end

        render json: paginate(traditional_authorities.order(:name))
      end

      def destroy
        trad_auth = TraditionalAuthority.find(params[:id])

        ActiveRecord::Base.transaction do
          trad_auth.villages.destroy_all
          trad_auth.destroy!
        end

        render json: { message: "Traditional Authority and associated villages successfully deleted" }, status: :ok
        rescue ActiveRecord::RecordNotDestroyed => e
          render json: { error: e.message }, status: :unprocessable_entity
      end
      def update()
        ta = TraditionalAuthority.find(params[:id])
        ta.update!(
          name: params[:name] || ta.name,
          district_id: params[:district_id] || ta.district_id,
          date_created: Time.current,
          creator: User.current.id
        )
        render json: { data:ta.reload}
      end
    end
  end
end
