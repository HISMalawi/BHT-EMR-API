class AddLimsAcknowledgementStatusToCentralizedMigration < ActiveRecord::Migration[8.0]
  def change
    id = GlobalProperty.unscoped.find_by_property('current_health_center_id')&.property_value
    Location.current = Location.find(id)

    ActiveRecord::Base.connection.execute <<~SQL
      SET sql_mode = 'ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
    SQL
    unless column_exists?(
      :lims_acknowledgement_statuses, :site_id
    )
      add_column :lims_acknowledgement_statuses, :site_id, :bigint,
                 default: current_health_center_id
    end
    change_column :lims_acknowledgement_statuses, :site_id, :bigint, default: 0 if column_exists?(
      :lims_acknowledgement_statuses, :site_id
    )

    t = 'lims_acknowledgement_statuses'.to_sym
    # Add UUID column if it doesn't exist
    add_column t, :uuid, :string, limit: 36 unless column_exists?(t, :uuid)

    # Set UUID values for existing records
    execute("UPDATE #{t} SET uuid = UUID() WHERE uuid IS NULL")

    # Make the column non-null after setting values
    change_column t, :uuid, :string, null: false, limit: 36

    # Add unique index
    add_index t, :uuid, unique: true, length: 36
  end

  def current_health_center_id
    Location.site_id
  end
end
