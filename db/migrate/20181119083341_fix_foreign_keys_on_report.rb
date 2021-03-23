class FixForeignKeysOnReport < ActiveRecord::Migration[5.2]
  def up
    execute('SET FOREIGN_KEY_CHECKS=0')
    begin
      execute('ALTER TABLE reporting_report_design
               DROP FOREIGN KEY `report_definition_id for reporting_report_design`')
    rescue StandardError => e
      logger.warn("Failed to drop foreign key `report_definition_id for reporting_report_design` of reporting_report_design: #{e}")
    end
    execute('ALTER TABLE reporting_report_design
             ADD CONSTRAINT `report_definition_id for reporting_report_design`
             FOREIGN KEY (report_definition_id) REFERENCES report_def (report_def_id)')
    execute('SET FOREIGN_KEY_CHECKS=1')
  end

  def down
    execute('SET FOREIGN_KEY_CHECKS=0')
    begin
      execute('ALTER TABLE reporting_report_design
               DROP FOREIGN KEY `report_definition_id for reporting_report_design`')
    rescue StandardError => e
      logger.warn("Failed to drop foreign key `report_definition_id for reporting_report_design` of reporting_report_design: #{e}")
    end
    execute('ALTER TABLE reporting_report_design
             ADD CONSTRAINT `report_definition_id for reporting_report_design`
             FOREIGN KEY (report_definition_id) REFERENCES serialized_object (serialized_object_id)')
    execute('SET FOREIGN_KEY_CHECKS=1')
  end
end
