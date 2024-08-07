# frozen_string_literal: true

class CreateLimsAcknowledgementStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :lims_acknowledgement_statuses, id: false do |t|
      t.integer :order_id, primary_key: true
      t.integer :test, null: false
      t.datetime :date_received, null: false
      t.datetime :date_pushed, null: true
      t.string :acknowledgement_type, null: false
      t.boolean :pushed, null: false, default: false
    end

    add_foreign_key :lims_acknowledgement_statuses, :orders, column: :order_id, primary_key: :order_id
    add_foreign_key :lims_acknowledgement_statuses, :concept, column: :test, primary_key: :concept_id
  end
end
