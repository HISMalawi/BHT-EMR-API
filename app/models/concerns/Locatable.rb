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
    # Check if table exists and has location_id column before setting up associations
    # This prevents errors during schema loading when tables don't exist yet
    begin
      if ActiveRecord::Base.connection.table_exists?(table_name) && location_id_column?

        belongs_to :location, foreign_key: :location_id, primary_key: :location_id, optional: true

        default_scope { where(location_id: current_location_id) }
        validates :location_id, presence: true
        before_save :set_location_id

      end
    rescue ActiveRecord::NoDatabaseError, Mysql2::Error
      # Database doesn't exist yet, skip setup
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
