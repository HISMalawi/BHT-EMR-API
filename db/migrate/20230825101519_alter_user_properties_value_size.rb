# frozen_string_literal: true

# AlterUserPropertiesValueSize
class AlterUserPropertiesValueSize < ActiveRecord::Migration[5.2]
  # change_column property_value from text to longtext
  def up
    change_column :user_property, :property_value, :text, limit: 4_294_967_295, default: nil
  end
end
