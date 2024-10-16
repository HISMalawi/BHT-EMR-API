class PasswordPolicies < ActiveRecord::Migration[7.0]
  def change
    props = GlobalProperty
    user_props = UserProperty

    # enable password policy
    handle_policy(props:, property: 'password_policy_enabled', property_value: 'true')

    # set password reset interval to 30 days
    handle_policy(props:, property: 'password_reset_interval', property_value: '30')

    # set all user props to forcefully reset passwords
    reset_period = Date.today - 31.days
    User.all.each do |user|
      uprop = user_props.find_or_initialize_by(user_id: user.id, property: 'last_password_reset')
      if uprop.new_record?
        uprop.property_value = reset_period
        uprop.save!

        next
      end
      uprop.update(property_value: reset_period)
    end
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
