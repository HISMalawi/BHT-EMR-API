# frozen_string_literal: true


# InactivityMigration
class InactivityMigration < ActiveRecord::Migration[7.0]
  def change
    props = GlobalProperty

    handle_policy(props:, property: 'inactivity_timeout', property_value: 15)
  end

  def handle_policy(props:, property:, property_value:)
    policy = props.find_by_property(property)
    if policy.blank?
      props.create!(property:, property_value:)
    else
      policy.update!(property_value:)
    end
  end
end
