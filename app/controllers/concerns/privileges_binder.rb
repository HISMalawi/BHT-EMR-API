# frozen_string_literal: true

require 'active_support/concern'

# Binds and enforces privileges on controller actions
module PrivilegesBinder
  extend ActiveSupport::Concern

  included do
    before_action :enforce_privileges
  end

  class_methods do
    # Attach a privilege to an action or more.
    #
    # Example:
    #
    #   class Foobar < ApplicationController
    #     ...
    #     bind_privilege 'edit_foobar', [:create, :update, :delete]  # Multiple actions
    #     bind_privilege 'view_foobar',  :index   # Single action
    #     ...
    #
    # This will limit access to :create and :index actions to users with roles that
    # have the privileges 'edit_foobar' and 'view_foobar' respectively.
    def bind_privilege(privilege_name, actions)
      # logger.debug "Binding actions (#{action}) to privilege (#{privilege_name})"
      privilege_name = privilege_name.to_s
      if actions.respond_to? :each
        actions.each do |action|
          # logger.debug "Binding privilege (#{privilege_name}) to action (#{action})"
          privilege_map[action.to_s] = privilege_name
        end
      else
        # logger.debug "Binding privilege (#{privilege_name}) to action (#{actions})"
        privilege_map[action.to_s] = privilege_name
      end
    end
  end

  # Limits access to a particular action to users having a privilige
  # to perform that action (see method bind_privilege).
  def enforce_privileges
    logger.debug "Enforcing privileges on action (#{action_name})"
    privilege_map = self.class.privilege_map

    # If no privilege is attached or no user is logged in then it is assumed
    # that action is accessible to everyone
    unless privilege_map.key?(action_name.to_s) && @logged_in_user
      logger.debug 'Aborting privilege enforcement - action not bound to privilege or user not logged in'
      return true
    end

    has_privilege = @logged_in_user.role.privileges.where(
      name: privilege_map[action_name.to_s]
    ).size == 1
    unless has_privilege
      logger.debug "User, #{@logged_in_user}, denied access to action, #{action_name}!"
      render json: { 'errors': ['User not allowed to perform action'] }, status: :not_found
      return false
    end

    logger.debug "User, #{@logged_in_user.username}, granted access to action, #{action_name}"
    true
  end
end
