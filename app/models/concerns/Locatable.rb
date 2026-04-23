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
    if location_id_column?

      belongs_to :location, foreign_key: :location_id, primary_key: :location_id, optional: true

      default_scope { where(location_id: current_location_id) }
      validates :location_id, presence: true
      before_save :set_location_id

    end
  end

  def set_location_id
    self.location_id ||= current_location_id
  end

  class_methods do
    def location_id_column?
      column_names.include?('location_id')
    end

    def current_location_id
      User.current&.location&.id || Location.current&.id
    end
  end
end

# rubocop:enable Style/Documentation, Naming/FileName
