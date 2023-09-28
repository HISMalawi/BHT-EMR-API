# frozen_string_literal: true

# AlterUserPropertiesValueSize
class AlterUserPropertiesValueSize < ActiveRecord::Migration[5.2]
  def change
    # change_column property_value from text to longtext
    change_column :user_property, :property_value, :text, limit: 4294967295, default: nil
  end
end
