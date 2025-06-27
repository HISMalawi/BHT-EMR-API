# frozen_string_literal: true

class AddDeactivatedOnToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :deactivated_on, :datetime, default: nil unless column_exists?(:users, :deactivated_on)
  end
end
