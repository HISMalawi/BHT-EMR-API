# rubocop:disable Naming/FileName
# frozen_string_literal: true

# rubocop:disable Style/Documentation

# this class is responsible for assigning a
# site id to a record on save

# when a table has a site id attached to it,
# make sure its assigned during save
# the site_id is collected from the logged in user who belongs to a location

module Locatable
  extend ActiveSupport::Concern

  included do
    if site_id_column?

      default_scope { where(site_id: current_location_id) }
      validates :site_id, presence: true
      before_save :set_site_id

    end
  end

  def set_site_id
    self.site_id ||= current_location_id
  end

  class_methods do
    def site_id_column?
      column_names.include?('site_id')
    end

    def current_location_id
      User.current&.current_location&.id || Location.current_health_center&.id
    end
  end
end

# rubocop:enable Style/Documentation, Naming/FileName
