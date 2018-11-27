class AlterRefDefIdForeignKeyConstraintOnReport < ActiveRecord::Migration[5.2]
  def up
    execute "ALTER TABLE `reporting_report_design`
             DROP FOREIGN KEY `report_definition_id for reporting_report_design`"
    execute "ALTER TABLE `reporting_report_design`
             ADD CONSTRAINT `report_definition_id for reporting_report_design`
             FOREIGN KEY (`report_definition_id`) REFERENCES `report_def` (`report_def_id`)"
  end

  def down
    execute "ALTER TABLE `reporting_report_design`
             DROP FOREIGN KEY `report_definition_id for reporting_report_design`"
    execute "ALTER TABLE `reporting_report_design`
             ADD CONSTRAINT `report_definition_id for reporting_report_design`
             FOREIGN KEY (`report_definition_id`) REFERENCES `serialized_object` (`serialized_object_id`)"
  end
end
