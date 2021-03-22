# frozen_string_literal: true

require_relative '../../app/services/nlims'

namespace :nlims do
  DEFAULT_USER = 'admin'
  DEFAULT_PASSWORD = 'knock_knock'

  desc 'Create NLIMS user for the application'
  task create_user: :environment do
    lims = NLims.new

    connection = lims.temp_auth
    health_center_id = GlobalProperty.find_by(property: 'current_health_center_id').property_value
    raise 'Global property current_health_center_id not set' unless health_center_id

    lims.create_user(location: Location.find(health_center_id).name,
                     app_name: config['lims_app_name'],
                     username: config['lims_username'],
                     password: config['lims_password'],
                     token: connection.token,
                     partner: config['lims_partner'])

    print "Successfully created lims user: #{config['lims_username']}"
  end

  def config
    @config ||= YAML.load_file(Rails.root.join('config', 'application.yml'))
  end
end
