# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
ActiveRecord::Base.connection.execute <<~SQL
  UPDATE users SET uuid = UUID() WHERE uuid IS NULL
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE encounter SET uuid = UUID() WHERE uuid IS NULL
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE obs SET uuid = UUID() WHERE uuid IS NULL
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE users MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

# execute alter table and have uuid as not null and unique
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE encounter MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

# execute alter table and have uuid as not null and unique
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE obs MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE active_list SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE active_list MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE active_list_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE active_list_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE cohort SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE cohort MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_answer SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_answer MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_class SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_class MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_datatype SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_datatype MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_description SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_description MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_map SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_map MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_name SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_name MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_name_tag SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_name_tag MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_proposal SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_proposal MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_set SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_set MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_source SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_source MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE concept_state_conversion SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE concept_state_conversion MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE drug SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE drug MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE encounter SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE encounter MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE encounter_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE encounter_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE field SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE field MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE field_answer SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE field_answer MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE field_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE field_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE form SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE form MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE form_field SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE form_field MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE global_property SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE global_property MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE hl7_in_archive SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE hl7_in_archive MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE hl7_in_error SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE hl7_in_error MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE hl7_in_queue SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE hl7_in_queue MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE hl7_source SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE hl7_source MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE location SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE location MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE location_tag SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE location_tag MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE logic_rule_definition SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE logic_rule_definition MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE logic_rule_token SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE logic_rule_token MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE logic_token_registration SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE logic_token_registration MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE note SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE note MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE notification_alert SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE notification_alert MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE notification_alert_recipient SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE notification_alert_recipient MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE notification_template SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE notification_template MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE obs SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE obs MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE order_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE order_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE orders SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE orders MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patient_identifier SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patient_identifier_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patient_program SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_program MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patient_state SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_state MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patientflags_flag SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patientflags_flag MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patientflags_tag SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patientflags_tag MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE person SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE person MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE person_address SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE person_address MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE person_attribute SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE person_attribute MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE person_attribute_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE person_attribute_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE person_name SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE person_name MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE privilege SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE privilege MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE program SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE program MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE program_workflow SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE program_workflow MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE program_workflow_state SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE program_workflow_state MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE regimen_drug_order SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE regimen_drug_order MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE relationship SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE relationship MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE relationship_type SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE relationship_type MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE report_object SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE report_object MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE report_schema_xml SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE report_schema_xml MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE reporting_report_design SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE reporting_report_design MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE reporting_report_design_resource SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE reporting_report_design_resource MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE role SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE role MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE scheduler_task_config SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE scheduler_task_config MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE serialized_object SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE serialized_object MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE task SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE task MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE users SET uuid = UUID() WHERE uuid IS NULL
SQL
ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE users MODIFY uuid VARCHAR(38) NOT NULL UNIQUE
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier ADD patient_identifier_id INT;
SQL
# SET @row_number = 0;
# UPDATE patient_identifiers
# SET patient_identifier_id = (@row_number := @row_number + 1);
# implement the above in ruby
ActiveRecord::Base.connection.execute <<~SQL
  SET @row_number = 0;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  UPDATE patient_identifier SET patient_identifier_id = (@row_number := @row_number + 1);
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier DROP FOREIGN KEY defines_identifier_type;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier DROP FOREIGN KEY identifies_patient;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier DROP FOREIGN KEY patient_identifier_ibfk_2;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier DROP KEY uuid;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier DROP PRIMARY KEY;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier ADD PRIMARY KEY (patient_identifier_id);
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier MODIFY patient_identifier_id INT NOT NULL AUTO_INCREMENT;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier MODIFY uuid VARCHAR(38) NOT NULL UNIQUE;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier ADD CONSTRAINT defines_identifier_type FOREIGN KEY (identifier_type) REFERENCES patient_identifier_type (patient_identifier_type_id);
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier ADD CONSTRAINT identifies_patient FOREIGN KEY (patient_id) REFERENCES patient (patient_id) ON UPDATE CASCADE;
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier ADD CONSTRAINT patient_identifier_ibfk_2 FOREIGN KEY (location_id) REFERENCES location (location_id);
SQL

ActiveRecord::Base.connection.execute <<~SQL
  ALTER TABLE patient_identifier AUTO_INCREMENT = #{PatientIdentifier.count + 1};
SQL
