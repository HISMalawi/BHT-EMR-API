class PasswordPolicies < ActiveRecord::Migration[7.0]
  def change
    props = GlobalProperty
    user_props = UserProperty

    # enable password policy
    props.find_by_property('password_policy_enabled')&.update(property_value: 'true')

    # set password reset interval to 30 days
    props.find_by_property('password_reset_interval')&.update(property_value: '30')

    # set all user props to forcefully reset passwords
    User.all.each do |user|
      uprop = user_props.find_or_initialize_by(user_id: user.id, property: 'last_password_reset')
      if uprop.new_record?
        uprop.property_value = Date.today - 31.days
        uprop.save!

        next
      end
      uprop.update(property_value: Date.today - 31.days)
    end
  end
end
