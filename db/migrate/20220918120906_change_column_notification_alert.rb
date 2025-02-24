# frozen_string_literal: true

class ChangeColumnNotificationAlert < ActiveRecord::Migration[5.2]
  def up
    change_column :notification_alert, :text, :text
  end
end
