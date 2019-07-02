#!/bin/bash

usage() {
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|test|production"
}

ENV=$1

if [ -z "$ENV" ]; then
  usage
  exit 255
fi

set -x # turns on stacktrace mode which gives useful debug information

export RAILS_ENV=$ENV
rails db:environment:set RAILS_ENV=$ENV

USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
ANCDATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['anc_database']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

echo "=================merging patients in ANC only into ART database"

start_now=$(date +”%T”)
echo "the script is starting at: " start_now 

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

SET foreign_key_checks = 0;
/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) from $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) from $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);


/* dropping and creating person_back_up  */
DROP TABLE IF EXISTS $ANCDATABASE.anc_art_patients_with_voided_art_identifier;

CREATE TABLE $ANCDATABASE.anc_art_patients_with_voided_art_identifier as
SELECT a.patient_id AS ANC_patient_id,
    p.patient_id AS ART_patient_id,
    per.gender AS ART_gender,
    per.birthdate AS ART_birthdate,
    per.voided AS per_voided,
    p.identifier AS ART_identifier,
    p.identifier_type,
    2 AS new_identifier_type,
    p.void_reason,
    p.voided AS pi_voided,
    p.creator AS ART_creator,
    p.location_id, p.preferred, p.date_created,
    pn.family_name,
    pn.given_name
FROM $DATABASE.patient_identifier p
 INNER JOIN $DATABASE.person per ON per.person_id = p.patient_id
 INNER JOIN $DATABASE.person_name pn ON pn.person_id = p.patient_id
 INNER JOIN $ANCDATABASE.anc_remaining_patient a on a.identifier = p.identifier
WHERE a.identifier  NOT IN (SELECT anc_d.identifier FROM $ANCDATABASE.anc_remaining_diff_gender anc_d);

/* Insert patient_identifier  */
INSERT INTO $DATABASE.patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,   void_reason,  uuid)
SELECT p.ART_patient_id, p.ART_identifier, p.new_identifier_type,  p.preferred,  p.location_id,  p.ART_creator,  p.date_created,  p.void_reason, (SELECT uuid()) 
FROM $ANCDATABASE.anc_art_patients_with_voided_art_identifier p 
WHERE p.pi_voided = 1 and p.void_reason like  '% new ID:%';

/* creating encounters table back-up  */  
DROP TABLE if exists $ANCDATABASE.encounter_back;

CREATE TABLE $ANCDATABASE.encounter_back as
SELECT (SELECT @max_encounter_id + e.encounter_id) AS encounter_id,
    e.encounter_type, a.ART_patient_id AS patient_id, provider_id, e.location_id,
    e.form_id, e.encounter_datetime, c.ART_user_id AS creator, e.date_created,
    e.voided, e.voided_by, e.date_voided, e.void_reason, e.uuid, e.changed_by, e.date_changed
FROM $ANCDATABASE.anc_art_patients_with_voided_art_identifier a
  INNER JOIN $ANCDATABASE.encounter e ON e.patient_id = a.ANC_patient_id AND e.voided = 0
  INNER JOIN $ANCDATABASE.user_bak c ON c.ANC_user_id = e.creator
WHERE a.pi_voided = 1 AND a.void_reason LIKE '% new ID:%';


/* insert ANC encounters into ART database  */  
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
SELECT encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (SELECT uuid()), changed_by, date_changed, 12 
from $ANCDATABASE.encounter_back order by patient_id;

/* creating orders back-up  */
DROP TABLE if exists $ANCDATABASE.orders_bak;

CREATE TABLE $ANCDATABASE.orders_bak as
SELECT (SELECT @max_order_id + o.order_id) AS ART_order_id,
    order_id AS ANC_order_id, o.order_type_id, o.concept_id,
    orderer, (SELECT @max_encounter_id + o.encounter_id) AS encounter_id,
    o.instructions, o.start_date, o.auto_expire_date, o.discontinued, o.discontinued_date,
    o.discontinued_by, o.discontinued_reason, c.ART_user_id as creator, o.date_created, o.voided,
    o.voided_by, o.date_voided, o.void_reason, a.ART_patient_id AS patient_id,
    o.accession_number, (SELECT @max_obs_id + o.obs_id) AS obs_id, o.uuid, o.discontinued_reason_non_coded
FROM $ANCDATABASE.orders o
  INNER JOIN $ANCDATABASE.anc_art_patients_with_voided_art_identifier a ON a.ANC_patient_id = o.patient_id AND o.voided = 0
  INNER JOIN $ANCDATABASE.user_bak c ON c.ANC_user_id = o.creator
WHERE a.pi_voided = 1 AND a.void_reason LIKE '% new ID:%';

/* insert ANC orders into ART database  */
INSERT INTO $DATABASE.orders (order_id,  order_type_id,  concept_id,  orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT ART_order_id,  order_type_id,  concept_id,  orderer, encounter_id,  instructions, start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id, accession_number, obs_id, (SELECT UUID()),  discontinued_reason_non_coded 
FROM $ANCDATABASE.orders_bak;

/* insert ANC drug_orders into ART database */
INSERT INTO $DATABASE.drug_order (order_id,  drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT ART_order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity FROM $ANCDATABASE.drug_order d 
inner join $ANCDATABASE.orders_bak o on o.ANC_order_id = d.order_id; 

/* creating obs back-up */
DROP TABLE if exists $ANCDATABASE.obs_bak;

CREATE TABLE $ANCDATABASE.obs_bak as
SELECT (SELECT @max_obs_id + o.obs_id) AS obs_id, a.ART_patient_id AS person_id,
    o.concept_id, (SELECT @max_encounter_id + o.encounter_id) AS encounter_id,
    (SELECT @max_order_id + o.order_id) AS order_id, o.obs_datetime, o.location_id,
    o.obs_group_id, o.accession_number, o.value_group_id, o.value_boolean, o.value_coded,
    o.value_coded_name_id, o.value_drug, o.value_datetime, o.value_numeric, o.value_modifier,
    o.value_text, o.date_started, o.date_stopped, o.comments, c.ART_user_id AS creator, o.date_created,
    o.voided, o.voided_by, o.date_voided, o.void_reason, o.value_complex, o.uuid
FROM $ANCDATABASE.obs o
  INNER JOIN $ANCDATABASE.anc_art_patients_with_voided_art_identifier a ON a.ANC_patient_id = o.person_id AND o.voided = 0
  INNER JOIN $ANCDATABASE.user_bak c ON c.ANC_user_id = o.creator
WHERE a.pi_voided = 1 AND a.void_reason LIKE '% new ID:%';

/* insert ANC obs into ART database */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT obs_id, person_id,  concept_id, encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric, value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided, voided_by,  date_voided,  void_reason,  value_complex,  (SELECT UUID()) 
FROM $ANCDATABASE.obs_bak ORDER BY obs_id;

/* creating patient_program back-up */
DROP TABLE if exists $ANCDATABASE.patient_program_bak;

CREATE TABLE $ANCDATABASE.patient_program_bak as

SELECT (SELECT @max_patient_program_id + patient_program_id) AS ART_patient_program_id, 
    p.patient_program_id AS ANC_patient_program_id, a.ART_patient_id AS patient_id,
    p.program_id, p.date_enrolled, p.date_completed, c.ART_user_id AS creator, p.date_created, p.changed_by,
    p.date_changed, p.voided, p.voided_by, p.date_voided, p.void_reason, p.uuid, p.location_id
FROM $ANCDATABASE.patient_program p
  INNER JOIN $ANCDATABASE.anc_art_patients_with_voided_art_identifier a ON a.ANC_patient_id = p.patient_id AND p.voided = 0
  INNER JOIN $ANCDATABASE.user_bak c ON c.ANC_user_id = p.creator
WHERE a.pi_voided = 1 AND a.void_reason LIKE '% new ID:%';

/* insert ANC patient_program into ART database */
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
SELECT ART_patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  changed_by,  voided, voided_by,  date_voided,  void_reason,  (SELECT UUID()),  location_id 
from $ANCDATABASE.patient_program_bak f order by patient_id;

/* insert ANC patient_state into ART database */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT p.ART_patient_program_id AS patient_program_id, f.state,
    f.start_date, f.end_date, c.ART_user_id, f.date_created, f.changed_by, f.date_changed,
    f.voided, f.voided_by, f.date_voided, f.void_reason, (SELECT UUID())
FROM $ANCDATABASE.patient_state f
  INNER JOIN $ANCDATABASE.patient_program_bak p ON p.ANC_patient_program_id = f.patient_program_id
  INNER JOIN $ANCDATABASE.user_bak c ON c.ANC_user_id = p.creator
ORDER BY f.patient_program_id;


/* UPDATE Observation (61) encounter_type to ANC Examination (98) encounter_type */
UPDATE $DATABASE.encounter set encounter_type = 98 where encounter_type = 61;

/* UPDATE bed nets that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE concept_id = 2723 and value_text IN ('Given during previous ANC visit for current pregnancy', 'Given Today', 'Yes');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE concept_id = 2723 and value_text IN ('No', 'Not given today or during current pregnancy');

UPDATE $ANCDATABASE.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE concept_id = 2723 and value_text IN ('Unknown');

/* UPDATE Pre-eclampsia, Previous HIV Test, etc that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE value_text = 'Yes';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE value_text = 'No';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE value_text = 'Unknown';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 703, value_coded_name_id = 718 WHERE value_text = 'Positive';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 664, value_coded_name_id = 678 WHERE value_text = 'Negative';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 2475, value_coded_name_id = 5944 WHERE value_text = 'Not Done';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 9436, value_coded_name_id = 12655 WHERE value_text = 'Inconclusive';

/* UPDATE Condition at Birth that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 2895, value_coded_name_id = 3115 WHERE concept_id = 7998 and value_text IN ('Alive');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 7804, value_coded_name_id = 10669 WHERE concept_id = 7998 and value_text IN ('Fresh Still Birth (FSB)');


UPDATE $DATABASE.obs SET value_text = null, value_coded = 7803, value_coded_name_id = 10668 WHERE concept_id = 7998 and value_text IN ('Macerated Still Birth (MSB)');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 7975, value_coded_name_id = 10922 WHERE concept_id = 7998 and value_text IN ('Still Birth');

UPDATE $DATABASE.encounter SET provider_id = creator WHERE provider_id = 0;

UPDATE $DATABASE.encounter SET provider_id = creator WHERE provider_id IS NULL;

SET foreign_key_checks = 1;

EOF
