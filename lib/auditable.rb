require 'logger'

# Gives ActiveRecord models an auditable Trait
module Auditable
  before_save :update_audit_trail

  class << self
    private

    LOGGER = Logger.new STDOUT

    # Saves current user after every save
    def update_audit_trail
      current_user = User.current_user

      LOGGER.warn 'update_audit_trail called outside login' unless current_user

      self.changed_by = current_user ? current_user.id : nil
      self.date_changed = Time.now
    end
  end
end
