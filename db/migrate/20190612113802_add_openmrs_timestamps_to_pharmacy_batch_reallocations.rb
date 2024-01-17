class AddOpenmrsTimestampsToPharmacyBatchReallocations < ActiveRecord::Migration[5.2]
  def up
    ActiveRecord::Base.connection.execute(
      <<~SQL
        ALTER TABLE pharmacy_batch_item_reallocations
          ADD COLUMN date_created DATETIME NOT NULL,
          ADD COLUMN creator INTEGER NOT NULL,
          ADD COLUMN date_changed DATETIME NOT NULL,
          ADD COLUMN voided SMALLINT,
          ADD COLUMN date_voided DATETIME,
          ADD COLUMN voided_by INTEGER,
          ADD COLUMN void_reason VARCHAR(255)
      SQL
    )

    ActiveRecord::Base.connection.execute(
      <<~SQL
        UPDATE pharmacy_batch_item_reallocations
        SET date_created = created_at,
            date_changed = updated_at
      SQL
    )

    ActiveRecord::Base.connection.execute(
      <<~SQL
        ALTER TABLE pharmacy_batch_item_reallocations
        DROP COLUMN created_at,
        DROP COLUMN updated_at
      SQL
    )
  end

  def down
    ActiveRecord::Base.connection.execute(
      <<~SQL
        ALTER TABLE pharmacy_batch_item_reallocations
          ADD COLUMN created_at DATETIME NOT NULL DEFAULT NOW(),
          ADD COLUMN updated_at DATETIME NOT NULL DEFAULT NOW()
      SQL
    )

    ActiveRecord::Base.connection.execute(
      <<~SQL
        UPDATE pharmacy_batch_item_reallocations
          SET created_at = date_created,
              updated_at = date_changed
      SQL
    )

    ActiveRecord::Base.connection.execute(
      <<~SQL
        ALTER TABLE pharmacy_batch_item_reallocations
          DROP COLUMN date_created,
          DROP COLUMN creator,
          DROP COLUMN date_changed,
          DROP COLUMN voided,
          DROP COLUMN date_voided,
          DROP COLUMN voided_by,
          DROP COLUMN void_reason
      SQL
    )
  end
end
