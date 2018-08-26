# frozen_string_literal: true

# Gives ActiveRecord models an auditable behaviour
#
# Models with the Auditable behaviour automagically get their
# date_changed and changed_by field set to the currently logged
# in user.
#
# USAGE:
#  class ApplicationRecord < ActiveRecord::Model
#    include Auditable
#    ...
#  end
module Auditable
  extend ActiveSupport::Concern

  included do
    before_save :update_audit_trail
  end

  # Saves current user after every save
  def update_audit_trail
    user = User.current

    Rails.logger.warn 'update_audit_trail called outside login' unless user

    self.changed_by = user ? user.id : nil
    self.date_changed = Time.now
  end
end
