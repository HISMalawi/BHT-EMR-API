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

echo "===========merge ANC data into ART database==============="

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

SET foreign_key_checks = 0;

/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) from $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) from $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);
SET @max_user_id := (select max(user_id) from $DATABASE.users);

/* update ANC admin user to admini  */
UPDATE $ANCDATABASE.users SET username = 'admini' WHERE user_id = 1;

/* Create ANC back-up table  */
drop table if exists $ANCDATABASE.user_bak;

create table $ANCDATABASE.user_bak as
SELECT user_id as ANC_user_id, (SELECT @max_user_id + user_id) AS ART_user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  (SELECT @max_user_id + creator) as creator,  date_created,  (SELECT @max_user_id + changed_by) as changed_by,  date_changed,  (SELECT @max_patient_id + person_id) as person_id,  retired, (SELECT @max_user_id + retired_by) as retired_by,  date_retired,  retire_reason,  (SELECT UUID()),  authentication_token FROM $ANCDATABASE.users; 

/* insert users person table into ART person table  */
INSERT INTO $DATABASE.person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
select (select @max_patient_id + person_id) as person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, (SELECT @max_user_id + creator) AS creator, date_created, (SELECT @max_user_id + changed_by) AS changed_by, date_changed, voided, (SELECT @max_user_id + voided_by) AS voided_by, date_voided, void_reason, (select uuid())  from $ANCDATABASE.person  where person_id in (select person_id from $ANCDATABASE.users);

/* insert users names into ART  */
INSERT INTO $DATABASE.person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
select preferred, (select @max_patient_id + f.person_id) as person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, (SELECT @max_user_id + creator) AS creator, date_created, voided, (SELECT @max_user_id + voided_by) AS voided_by, date_voided, void_reason, (SELECT @max_user_id + changed_by) AS changed_by, date_changed, (select uuid())  from $ANCDATABASE.person_name f where f.person_id IN (SELECT person_id FROM $ANCDATABASE.users);

/* Insert ANC users  */
INSERT INTO $DATABASE.users (user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  creator,  date_created,  changed_by,  date_changed,  person_id,  retired,  retired_by,  date_retired,  retire_reason,  uuid,  authentication_token)
SELECT ART_user_id, system_id,  username,  password,  salt,  secret_question,  secret_answer, (SELECT @max_user_id + creator) AS creator,  date_created,  (SELECT @max_user_id + changed_by) AS changed_by,  date_changed, person_id,  retired, (SELECT @max_user_id + retired_by) AS retired_by,  date_retired,  retire_reason,  (SELECT UUID()),  authentication_token FROM $ANCDATABASE.user_bak; 

/* dropping and creating patient_details  */
drop table if exists $ANCDATABASE.ANC_patient_details;

create table $ANCDATABASE.ANC_patient_details As
SELECT anc_pi.patient_id AS ANC_patient_id, anc_pi.identifier AS ANC_identifier, art_pi.patient_id AS ART_patient_id, art_pi.identifier AS ART_identifier
FROM $ANCDATABASE.patient_identifier anc_pi
INNER JOIN $DATABASE.patient_identifier art_pi ON art_pi.identifier = anc_pi.identifier AND art_pi.voided = 0  AND anc_pi.voided = 0
INNER JOIN $DATABASE.person art_pa on art_pa.person_id = art_pi.patient_id AND art_pa.voided = 0
WHERE anc_pi.identifier_type IN (3) AND art_pi.identifier_type IN (2 , 3)
AND anc_pi.patient_id NOT IN (SELECT u.person_id FROM $ANCDATABASE.users u)
AND art_pa.gender = (SELECT anc_pa.gender FROM $ANCDATABASE.person anc_pa WHERE anc_pa.person_id = anc_pi.patient_id AND anc_pa.voided = 0)
GROUP BY anc_pi.patient_id;

/* creating encounters table back-up  */
drop table if exists $ANCDATABASE.encounter_back;

create table $ANCDATABASE.encounter_back as
SELECT (SELECT @max_encounter_id + e.encounter_id) as encounter_id, e.encounter_type, a.ART_patient_id AS patient_id, (SELECT @max_user_id + e.provider_id) AS provider_id, e.location_id, e.form_id, e.encounter_datetime, (SELECT @max_user_id + e.creator) AS creator, e.date_created, e.voided, (SELECT @max_user_id + voided_by) AS voided_by, e.date_voided, e.void_reason, e.uuid, (SELECT @max_user_id + e.changed_by) AS changed_by, e.date_changed FROM $ANCDATABASE.ANC_patient_details a INNER JOIN $ANCDATABASE.encounter e ON e.patient_id = a.ANC_patient_id and e.voided = 0;

/* insert ANC encounters into ART database  */
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
select encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (select uuid()), changed_by, date_changed, 12 from $ANCDATABASE.encounter_back order by patient_id;

/* creating orders back-up  */
drop table if exists $ANCDATABASE.orders_bak;

create table $ANCDATABASE.orders_bak as
SELECT (SELECT @max_order_id + o.order_id) as ART_order_id, order_id as ANC_order_id, order_type_id, concept_id, orderer, (SELECT @max_encounter_id + o.encounter_id) as encounter_id, instructions, start_date, auto_expire_date, discontinued, discontinued_date, discontinued_by, discontinued_reason, (SELECT @max_user_id + creator) AS creator, date_created, voided, (SELECT @max_user_id + voided_by) AS voided_by, date_voided, void_reason, e.ART_patient_id AS patient_id, accession_number, (SELECT @max_obs_id + o.obs_id) as obs_id, uuid, discontinued_reason_non_coded FROM $ANCDATABASE.orders o inner join $ANCDATABASE.ANC_patient_details e on e.ANC_patient_id = o.patient_id and o.voided = 0;

/* insert ANC orders into ART database  */
INSERT INTO $DATABASE.orders (order_id,  order_type_id,  concept_id,  orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT ART_order_id,  order_type_id,  concept_id,  orderer, encounter_id,  instructions, start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id, accession_number, obs_id,  (SELECT UUID()),  discontinued_reason_non_coded FROM $ANCDATABASE.orders_bak;

/* insert ANC drug_orders into ART database */
INSERT INTO $DATABASE.drug_order (order_id,  drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT ART_order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity FROM $ANCDATABASE.drug_order d inner join $ANCDATABASE.orders_bak o on o.ANC_order_id = d.order_id; 

/* creating obs back-up */
drop table if exists $ANCDATABASE.obs_bak;

create table $ANCDATABASE.obs_bak as
SELECT (SELECT @max_obs_id + o.obs_id) as obs_id, e.ART_patient_id AS person_id,  concept_id,  (SELECT @max_encounter_id + o.encounter_id) AS encounter_id,  (SELECT @max_order_id + o.order_id) AS order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments, (SELECT @max_user_id + creator) AS creator,  date_created,  voided,  (SELECT @max_user_id + voided_by) AS voided_by,  date_voided,  void_reason,  value_complex,  uuid FROM $ANCDATABASE.obs o inner join $ANCDATABASE.ANC_patient_details e on e.ANC_patient_id = o.person_id and o.voided = 0;
   
/* insert ANC obs into ART database */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT obs_id, person_id,  concept_id, encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric, value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided, voided_by,  date_voided,  void_reason,  value_complex,  (SELECT UUID()) FROM $ANCDATABASE.obs_bak ORDER BY obs_id;

/* creating patient_program back-up */
drop table if exists $ANCDATABASE.patient_program_bak;

create table $ANCDATABASE.patient_program_bak as
SELECT (SELECT @max_patient_program_id + patient_program_id) AS patient_program_id, e.ART_patient_id AS patient_id, program_id, date_enrolled, date_completed, (SELECT @max_user_id + creator) AS creator, date_created, (SELECT @max_user_id + changed_by) AS changed_by,  date_changed,  voided, (SELECT @max_user_id + voided_by) AS voided_by,  date_voided,  void_reason,  uuid,  location_id FROM $ANCDATABASE.patient_program p INNER JOIN $ANCDATABASE.ANC_patient_details e on e.ANC_patient_id = p.patient_id and p.voided = 0;

/* insert ANC patient_program into ART database */
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
select patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  changed_by,  voided, voided_by,  date_voided,  void_reason,  (SELECT UUID()),  location_id from $ANCDATABASE.patient_program_bak f order by patient_id;

/* insert ANC patient_state into ART database */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT (SELECT @max_patient_program_id + patient_program_id) as patient_program_id, state, start_date, end_date, (SELECT @max_user_id + creator) AS creator, date_created, (SELECT @max_user_id + changed_by) AS changed_by, date_changed, voided, (SELECT @max_user_id + voided_by) AS voided_by, date_voided, void_reason, (SELECT UUID()) FROM $ANCDATABASE.patient_state f ORDER BY patient_program_id;

/* Update Observation (61) encounter_type to ANC Examination (98) encounter_type */
update $DATABASE.encounter set encounter_type = 98 where encounter_type = 61;

/* Update bed nets that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE concept_id = 2723 and value_text IN ('Given during previous ANC visit for current pregnancy', 'Given Today', 'Yes');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE concept_id = 2723 and value_text IN ('No', 'Not given today or during current pregnancy');

UPDATE $ANCDATABASE.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE concept_id = 2723 and value_text IN ('Unknown');

/* Update Pre-eclampsia, Previous HIV Test, etc that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 1065, value_coded_name_id = 1102 WHERE value_text = 'Yes';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1066, value_coded_name_id = 1103 WHERE value_text = 'No';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 1067, value_coded_name_id = 1104 WHERE value_text = 'Unknown';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 703, value_coded_name_id = 718 WHERE value_text = 'Positive';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 664, value_coded_name_id = 678 WHERE value_text = 'Negative';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 2475, value_coded_name_id = 5944 WHERE value_text = 'Not Done';

UPDATE $DATABASE.obs SET value_text = null, value_coded = 9436, value_coded_name_id = 12655 WHERE value_text = 'Inconclusive';

/* Update Condition at Birth that were saved as value_text */
UPDATE $DATABASE.obs SET value_text = null, value_coded = 2895, value_coded_name_id = 3115 WHERE concept_id = 7998 and value_text IN ('Alive');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 7804, value_coded_name_id = 10669 WHERE concept_id = 7998 and value_text IN ('Fresh Still Birth (FSB)');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 7803, value_coded_name_id = 10668 WHERE concept_id = 7998 and value_text IN ('Macerated Still Birth (MSB)');

UPDATE $DATABASE.obs SET value_text = null, value_coded = 7975, value_coded_name_id = 10922 WHERE concept_id = 7998 and value_text IN ('Still Birth');

UPDATE $DATABASE.encounter SET provider_id = creator WHERE provider_id = 0;

UPDATE $DATABASE.encounter SET provider_id = creator WHERE provider_id IS NULL;

SET foreign_key_checks = 1;

EOF
echo "Start script 2 -----------------------------"
echo "Running script to migrate patients that are only in ANC"
./bin/anc_patients_only_patient_merge_script.sh development

echo "Start script 3 -----------------------------"
echo "Running script to migrate patients that have gender as the only difference"
./bin/anc_migrating_remaining_patients.sh development

echo "Start script 4 -----------------------------"
echo "Running script to migrate patients that are voided in ART but are active in ART"
./bin/anc_migrating_patients_with_voided_ART_identifier.sh development

echo "Start script 5 -----------------------------"
echo "Running script to migrate the remaining patient"
./bin/migrating_anc_last_patients.sh development

echo "Start script 6 -----------------------------"
echo "Running script to migrate the remaining patient"
./bin/anc_patients_with_duplicates_in_art.sh development

echo "Start script 7 -----------------------------"
echo "Dumping ANC_remaining_patients.csv file for patients that were not migrated"
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $ANCDATABASE < bin/ANC_remaining_patients.sql > ~/ANC_remaining_patients.csv

echo "Finished merging the data"
