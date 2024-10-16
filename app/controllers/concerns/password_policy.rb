module PasswordPolicy
  extend ActiveSupport::Concern

  class UserUpdateError < InvalidParameterError; end

  included do
    before_action :validate_password, only: [:update]
  end

  private

  def user_last_used_passwords_props(user:)
    UserProperty
      .where(user_id: user.id)
      .where("property like ?", ["last_used_password_%"])
  end

  def passwords_match?(saved_password:, password_input:)
    Digest::SHA1.hexdigest("#{password_input}#{user.salt}") == saved_password \
      || Digest::SHA512.hexdigest("#{password_input}#{user.salt}") == saved_password
  end

  def password_valid?(user:, password_input:)
    if password_input.length < 6
      raise UserUpdateError, "Password must be at least 6 characters in length"
    end

    # check if password is same as any of the last used passwords
    if user_last_used_passwords_props(user:).any?\
       { |up| passwords_match?(saved_password: up.property_value, password_input:) }
       
      raise UserUpdateError, "Password cannot be the same as previously used passwords"
    end

    true
  end

  def add_password_to_user_props(user:)
    pass_count = 1
    random = Random.rand(1..6)
    passwords_properties = self.user_last_used_passwords_props(user:).pluck("property")

    if (passwords_properties.length >= 6)
      # delete random saved password
      UserProperty
        .where(user_id: user.id)
        .where("property = ?", "last_used_password_#{random}")
        .delete_all
        
      passwords_properties.delete("last_used_password_#{random}")
    end

    while pass_count <= 6
      if !passwords_properties.include?("last_used_password_#{pass_count}")
        UserProperty
          .create(
            user_id: user.id,
            property: "last_used_password_#{pass_count}",
            property_value: Digest::SHA512.hexdigest("#{params[:password]}#{user.salt}"),
          )
        break
      else
        pass_count += 1
      end
    end
  end

  def validate_password
    ActiveRecord::Base.transaction do
      return true unless params[:password]

      user = User.find(params[:id])

      add_password_to_user_props(user:) if password_valid?(user:, password_input: params[:password])
    end
  end
end
