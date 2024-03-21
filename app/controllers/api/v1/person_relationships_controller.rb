# frozen_string_literal: true

module Api
  module V1
    class PersonRelationshipsController < ApplicationController
      def index
        filters = params.permit %i[person_b relationship]
        relationships = service.find_relationships filters
        render json: paginate(relationships)
      end

      def guardians
        render json: paginate(service.find_guardians).collect(&:relation)
      end

      def create
        relationship_type_id, relation_id = params.require %i[relationship_type_id relation_id]

        begin
          relationship_type = RelationshipType.find relationship_type_id
          person = Person.find relation_id
        rescue ActiveRecord::RecordNotFound => e
          return render json: { errors: e.message }, status: :bad_request
        end

        relationship = service.create_relationship person, relationship_type

        if relationship.errors.empty?
          render json: relationship, status: :created
        else
          render json: { errors: relationship.errors }, status: :bad_request
        end
      end

      def show
        render json: service.get_relationship(params[:id])
      end

      def destroy
        reason, = params.require %i[reason]

        if service.void_relationship params[:id], reason
          render status: :no_content
        else
          render json: { errors: ['Delete failed'] },
                 status: :internal_server_error
        end
      end

      private

      def service
        PersonRelationshipService.new Person.find(params[:person_id])
      end

      def person
        Person.find(params[:person_id])
      end
    end
  end
end
