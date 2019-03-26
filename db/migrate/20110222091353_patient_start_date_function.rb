class PatientStartDateFunction < ActiveRecord::Migration[5.2]
  def self.up
    ActiveRecord::Base.connection.execute <<EOF
DROP FUNCTION IF EXISTS patient_start_date;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION patient_start_date(patient_id int) RETURNS VARCHAR(10) 
DETERMINISTIC
BEGIN
DECLARE start_date VARCHAR(10);
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

set dispension_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED');
set arv_concept = (SELECT concept_id FROM concept_name WHERE name = "ANTIRETROVIRAL DRUGS");

set start_date = (SELECT DATE(obs_datetime) FROM obs WHERE voided = 0 AND person_id = patient_id AND concept_id = dispension_concept_id AND value_drug IN (SELECT drug_id FROM drug d WHERE d.concept_id IN (SELECT cs.concept_id FROM concept_set cs WHERE cs.concept_set = arv_concept)) ORDER BY DATE(obs_datetime) ASC LIMIT 1);

RETURN start_date;
END;
EOF
  end

  def self.down
    ActiveRecord::Base.connection.execute <<EOF
DROP FUNCTION IF EXISTS patient_start_date;
EOF
  end
end
