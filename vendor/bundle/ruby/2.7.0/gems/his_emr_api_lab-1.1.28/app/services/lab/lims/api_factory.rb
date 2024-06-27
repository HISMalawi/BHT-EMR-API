# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Creates LIMS Apis based on current configuration
    module ApiFactory
      def self.create_api
        return Lab::Lims::Api::BlackholeApi.new if Rails.env.casecmp?('test')

        case Lab::Lims::Config.preferred_api
        when /rest/i then Lab::Lims::Api::RestApi.new(Lab::Lims::Config.rest_api)
        when /couchdb/ then Lab::Lims::Api::CouchDbApi.new(config: Lab::Lims::Config.couchdb_api)
        else raise "Invalid lims_api configuration: #{Lab::Lims::Config.preferred_api}"
        end
      end
    end
  end
end
