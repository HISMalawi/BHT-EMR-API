# frozen_string_literal: true

module Api
  module V1
    class TotalsController < ApplicationController
      before_action :authenticate, except: %i[index]
      def index
         render json: {
          total_districts: District.all.count,
          total_TA:TraditionalAuthority.all.count,
          total_village: Village.all.count,
          total_relationships: RelationshipType.all.count,
          total_persons: Person.all.count,
          total_programs: Program.all.count
        }
      end
    end
  end
end
