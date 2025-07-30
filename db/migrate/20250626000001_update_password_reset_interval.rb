class UpdatePasswordResetInterval < ActiveRecord::Migration[7.0]
  def change
    # Enforce password reset interval to 90 days, overriding any existing value
    policy = GlobalProperty.find_by_property('password_reset_interval')
    
    if policy.present?
      policy.update!(property_value: '90')
    else
      # Create the policy if it doesn't exist
      GlobalProperty.create!(property: 'password_reset_interval', property_value: '90')

      # Force all users to reset passwords with the new 91-day period
      # This ensures compliance with the new 90-day policy
      reset_period = Date.today - 91.days
      User.all.each do |user|
        uprop = UserProperty.find_or_initialize_by(user_id: user.id, property: 'last_password_reset')
        if uprop.new_record?
          uprop.property_value = reset_period
          uprop.save!
          next
        end
        uprop.update(property_value: reset_period)
      end
    end
  end

  def down
    # Rollback to 30 days if migration is reversed
    policy = GlobalProperty.find_by_property('password_reset_interval')
    if policy.present?
      policy.update!(property_value: '30')
    end
  end
end
