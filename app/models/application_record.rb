class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_create :check_uuid

  def check_uuid
    if self.attributes.has_key?('uuid') && self.uuid.blank?
      self.uuid = SecureRandom.uuid
    end
  end
end
