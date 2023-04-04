# frozen_string_literal: true

# migration to add voidable columns to LIMS acknowledgement statuses
class AcknowledgementVoidable < ActiveRecord::Migration[5.2]
  def change
    # add the voided, voided_by, date_voided, void_reason columns
    add_column :lims_acknowledgement_statuses, :voided, :boolean, default: false
    add_column :lims_acknowledgement_statuses, :voided_by, :integer, default: nil
    add_column :lims_acknowledgement_statuses, :date_voided, :datetime, default: nil
    add_column :lims_acknowledgement_statuses, :void_reason, :string, default: nil

    # voided by reference to user
    add_foreign_key :lims_acknowledgement_statuses, :users, column: :voided_by, primary_key: :user_id
  end
end
