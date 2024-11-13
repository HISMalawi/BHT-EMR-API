# frozen_string_literal: true

require_relative '../../app/services/nlims'

namespace :nlims do
  DEFAULT_USER = 'admin'
  DEFAULT_PASSWORD = 'knock_knock'

  desc 'Create NLIMS user for the application'
  task create_user: :environment do
    lims = Nlims.new

    connection = lims.temp_auth
    health_center_id = GlobalProperty.find_by(property: 'current_health_center_id').property_value
    raise 'Global property current_health_center_id not set' unless health_center_id

    lims.create_user(location: Location.find(health_center_id).name,
                     app_name: lims_config['lims_app_name'],
                     username: lims_config['lims_username'],
                     password: lims_config['lims_password'],
                     token: connection.token,
                     partner: lims_config['lims_partner'])

    print "Successfully created lims user: #{lims_config['lims_username']}"
  end

  def lims_config
    @lims_config ||= YAML.load_file(Rails.root.join('config', 'application.yml'))
  end
end
