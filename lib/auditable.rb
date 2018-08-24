# frozen_string_literal: true

require 'logger'

# Gives ActiveRecord models an auditable Trait
module Auditable
  extend ActiveSupport::Concern

  included do
    before_save :update_audit_trail
  end

  # Saves current user after every save
  def update_audit_trail
    user = User.current_user

    Rails.logger.warn 'update_audit_trail called outside login' unless user

    self.changed_by = user ? user.id : nil
    self.date_changed = Time.now
  end
end
