# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Load LIMS' configuration files
    module Config
      class ConfigNotFound < RuntimeError; end

      class << self
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

        ##
        # Returns LIMS' application.yml configuration file
        def application
          YAML.load_file(find_config_path('application.yml'))
        end

        private

        ##
        # Looks for a config file in various LIMS installation directories
        #
        # Returns: a path to a file found
        def find_config_path(filename)
          paths = [
            "#{ENV['HOME']}/apps/nlims_controller/config/#{filename}",
            "/var/www/nlims_controller/config/#{filename}",
            Rails.root.parent.join("nlims_controller/config/#{filename}"),
            Rails.root.join('config/lims-couch.yml')
          ]

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
