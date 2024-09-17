class UpdatePrimaryKeyAndAutoIncrement < ActiveRecord::Migration[7.0]

  def up
    # Modify uuid to remove auto-increment (no need to touch visit_attributes table)
    execute <<-SQL
      ALTER TABLE visit
      MODIFY uuid BIGINT NOT NULL;
    SQL

    # Drop the primary key from uuid
    execute <<-SQL
      ALTER TABLE visit
      DROP PRIMARY KEY;
    SQL

    # Modify visit_id to be auto-increment and set as the primary key
    execute <<-SQL
      ALTER TABLE visit     
      MODIFY visit_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY;
    SQL
  end

             
end