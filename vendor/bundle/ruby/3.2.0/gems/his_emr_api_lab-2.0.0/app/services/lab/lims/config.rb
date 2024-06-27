# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Load LIMS' configuration files
    module Config
      # TODO: Replace this maybe with `Rails.application.configuration.lab.lims`
      # so that we do not have to directly mess with configuration files.

      class ConfigNotFound < RuntimeError; end

      class << self
        def preferred_api
          emr_api_application('lims_api')
        end

        ##
        # Returns LIMS' couchdb configuration file for the current environment (Rails.env)
        def couchdb
          config_path = begin
            find_config_path('couchdb.yml')
          rescue ConfigNotFound => e
            Rails.logger.error("Failed to find default LIMS couchdb config: #{e.message}")
            find_config_path('couchdb-lims.yml') # This can be placed in HIS-EMR-API/config
          end

          Rails.logger.debug("Using LIMS couchdb config: #{config_path}")

          YAML.load_file(config_path)[Rails.env]
        end

        def rest_api
          @rest_api ||= {
            protocol: emr_api_application('lims_protocol', 'http'),
            host: emr_api_application('lims_host'),
            port: emr_api_application('lims_port'),
            username: emr_api_application('lims_username'),
            password: emr_api_application('lims_password')
          }
        end

        def updates_socket
          @updates_socket ||= {
            'url' => emr_api_application('lims_realtime_updates_url')
          }
        end

        def updates_poll_frequency
          30 # Seconds
        end

        ##
        # Returns LIMS' application.yml configuration file
        def application
          @application ||= YAML.load_file(find_config_path('application.yml'))
        end

        ##
        # Returns LIMS' database.yml configuration file
        def database
          @database ||= YAML.load_file(find_config_path('database.yml'))
        end

        private

        def emr_api_application(param, fallback = nil)
          @emr_api_application ||= YAML.load_file(Rails.root.join('config', 'application.yml'))

          @emr_api_application.fetch(param) do
            raise ConfigNotFound, "Missing config param: #{param}" unless fallback

            fallback
          end
        end

        ##
        # Looks for a config file in various LIMS installation directories
        #
        # Returns: a path to a file found
        def find_config_path(filename)
          paths = [
            "#{Dir.home}/apps/nlims_controller/config/#{filename}",
            "/var/www/nlims_controller/config/#{filename}",
            Rails.root.parent.join("nlims_controller/config/#{filename}")
          ]

          paths = [Rails.root.join('config/lims-couchdb.yml'), *paths] if filename == 'couchdb.yml'

          paths.each do |path|
            Rails.logger.debug("Looking for LIMS couchdb config at: #{path}")
            return path if File.exist?(path)
          end

          raise ConfigNotFound, "Could not find a configuration file, checked: #{paths.join(':')}"
        end
      end
    end
  end
end
