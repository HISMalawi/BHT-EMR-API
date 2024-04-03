# frozen_string_literal: true

# This migration comes from lab (originally 20210807111531)
class AddDefaultToLimsOrderMapping < ActiveRecord::Migration[5.2]
  def up
    ActiveRecord::Base.connection.execute('ALTER TABLE lab_lims_order_mappings MODIFY revision VARCHAR(256) DEFAULT NULL')
  end

  def down; end
end
