class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_create :check_uuid

  def as_json(options = {})
    return super({}) if options[:ignore_includes]

    super(options)
  end

  def check_uuid
    if self.attributes.has_key?('uuid') && self.uuid.blank?
      self.uuid = SecureRandom.uuid
    end
  end

  class << self
    def use_healthdata_db
      establish_connection Rails.application.config.healthdata_db
    end
  end
end
