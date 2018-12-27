# frozen_string_literal: true

require_relative '../../app/services/nlims'

namespace :nlims do
  DEFAULT_USER = 'admin'
  DEFAULT_PASSWORD = 'knock_knock'

  config = YAML.load_file "#{Rails.root}/config/application.yml"

  desc 'Create NLIMS user for the application'
  task create_user: :environment do
    lims = NLims.new config

    connection = lims.temp_auth config[:lims_default_user],
                                config[:lims_default_password]

    current_health_center_id = GlobalProperty.find_by_name('current_health_center_id')
    raise 'Global property current_health_center_id not set' unless current_health_center_id

    lims.create_user location: Location.find(current_health_center_id).name,
                     app_name: config[:lims_app_name],
                     username: config[:lims_username],
                     password: config[:lims_password],
                     token: connection.token,
                     partner: config[:lims_partner]
  end
end
