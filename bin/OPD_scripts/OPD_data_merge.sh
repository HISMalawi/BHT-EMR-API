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
OPDDATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['opd_database']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

echo "merge OPD patients that are also in ART database"

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

SET foreign_key_checks = 0;

/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) from $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) from $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);
SET @max_user_id := (select max(user_id) from $DATABASE.users);

/* Create OPD back-up table */
DROP TABLE IF EXISTS $OPDDATABASE.user_backup;

create table $OPDDATABASE.user_backup as
SELECT user_id AS OPD_user_id, (SELECT @max_user_id + user_id) AS ART_user_id,
    system_id, username, password, salt, secret_question, secret_answer,
    (SELECT @max_user_id + creator) AS creator,
    date_created, (SELECT @max_user_id + changed_by) AS changed_by,
    date_changed, (SELECT @max_patient_id + person_id) AS person_id, retired,
    (SELECT @max_user_id + retired_by) AS retired_by, date_retired, retire_reason, (SELECT UUID()) as uuid, authentication_token
FROM $OPDDATABASE.users where username not in (select u.username from $OPDDATABASE.users u inner join $DATABASE.users a where u.username = a.username)
UNION
SELECT u.user_id AS OPD_user_id, a.user_id AS ART_user_id, a.system_id, a.username, a.password, a.salt, a.secret_question, a.secret_answer, a.creator, a.date_created, a.changed_by, a.date_changed, a.person_id, a.retired, a.retired_by, a.date_retired, a.retire_reason, a.uuid, a.authentication_token
FROM $OPDDATABASE.users u INNER JOIN $DATABASE.users a WHERE u.username = a.username;

/*  Create an opd users table to be migrated */
DROP TABLE IF EXISTS $OPDDATABASE.user_details_to_be_migrated;

create table $OPDDATABASE.user_details_to_be_migrated as
SELECT * FROM $OPDDATABASE.user_backup b 
WHERE b.OPD_user_id NOT IN (SELECT u.user_id FROM $OPDDATABASE.users u INNER JOIN $DATABASE.users a WHERE u.username = a.username);
 
/* insert users person table into ART person table */
INSERT INTO $DATABASE.person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
select u.person_id, p.gender, p.birthdate, p.birthdate_estimated, p.dead, p.death_date, p.cause_of_death, u.ART_user_id, p.date_created, p.changed_by, p.date_changed, p.voided, p.voided_by, p.date_voided, p.void_reason, (select uuid()) 
from $OPDDATABASE.person p inner join $OPDDATABASE.user_details_to_be_migrated u on u.person_id = p.person_id;

/* insert users names into ART */
INSERT INTO $DATABASE.person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
select preferred, u.person_id, f.prefix, f.given_name, f.middle_name, f.family_name_prefix, f.family_name, f.family_name2, f.family_name_suffix, f.degree, u.ART_user_id, f.date_created, f.voided, f.voided_by, f.date_voided, f.void_reason, f.changed_by, f.date_changed, (select uuid()) 
from $OPDDATABASE.person_name f 
inner join $OPDDATABASE.user_details_to_be_migrated u on u.person_id = f.person_id;

/* Insert OPD users */
INSERT INTO $DATABASE.users (user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer,  creator,  date_created,  changed_by,  date_changed,  person_id,  retired,  retired_by,  date_retired,  retire_reason,  uuid,  authentication_token)
SELECT ART_user_id,  system_id,  username,  password,  salt,  secret_question,  secret_answer, creator,  date_created,  changed_by,  date_changed, person_id,  retired, retired_by,  date_retired,  retire_reason,  (SELECT UUID()),  authentication_token FROM $OPDDATABASE.user_details_to_be_migrated; 

/* Create OPD patient details table */
drop table if exists $OPDDATABASE.opd_patient_details;

create table $OPDDATABASE.opd_patient_details
select p.person_id, p.gender, p.birthdate, p.death_date, pn.family_name, pn.given_name, pi.identifier, pi.identifier_type
from patient_identifier pi
 inner join person p on p.person_id = pi.patient_id
 inner join person_name pn on pn.person_id = p.person_id
where pi.voided = 0 and pi.identifier_type = 3 order by pi.patient_id;

/* Create ART patient details table */
drop table if exists $DATABASE.art_patient_details;

create table $DATABASE.art_patient_details
select p.person_id, p.gender, p.birthdate, p.death_date, pn.family_name, pn.given_name, pi.identifier, pi.identifier_type
from $DATABASE.patient_identifier pi
 inner join $DATABASE.person p on p.person_id = pi.patient_id
 inner join $DATABASE.person_name pn on pn.person_id = p.person_id
where pi.voided = 0 and pi.identifier_type IN (3, 2) 
and pi.patient_id not in (select person_id from $DATABASE.users) order by pi.patient_id;

/* Create patients that are not in ART */
DROP TABLE IF EXISTS $OPDDATABASE.opd_patient_details_in_art;

CREATE TABLE $OPDDATABASE.opd_patient_details_in_art AS
SELECT p.person_id AS OPD_patient_id, a.person_id AS ART_patient_id, p.gender as opd_gender, a.gender as art_gender, p.birthdate as opd_dob, a.birthdate as art_dob,
 p.family_name as opd_fname, a.family_name as art_fname, p.given_name as opd_gname, a.given_name as art_gname, p.identifier as opd_identifier, p.identifier_type as opd_identifier_type, a.identifier_type as art_identifier_type
FROM $OPDDATABASE.opd_patient_details p
INNER JOIN $DATABASE.art_patient_details a ON a.identifier = p.identifier
WHERE (a.given_name = p.given_name AND a.family_name = p.family_name) AND (p.gender = a.gender AND p.birthdate = a.birthdate);

/* creating encounters table back-up */
DROP TABLE IF EXISTS $OPDDATABASE.encounter_back;

CREATE TABLE $OPDDATABASE.encounter_back AS
SELECT (SELECT @max_encounter_id + e.encounter_id) as encounter_id, e.encounter_type, a.ART_patient_id AS patient_id,
	e.provider_id, e.location_id, e.form_id, e.encounter_datetime, e.creator, e.date_created, e.voided, e.voided_by, e.date_voided, e.void_reason, e.uuid, e.changed_by, e.date_changed 
FROM $OPDDATABASE.opd_patient_details_in_art a INNER JOIN $OPDDATABASE.encounter e ON e.patient_id = a.OPD_patient_id WHERE e.voided = 0 
group by e.patient_id, e.encounter_id, e.encounter_type, DATE(e.encounter_datetime);

/* insert OPD encounters into ART database */
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
select e.encounter_id, e.encounter_type, e.patient_id, ART_user_id, e.location_id, e.form_id, e.encounter_datetime, u.ART_user_id, e.date_created, e.voided, e.voided_by, e.date_voided, e.void_reason, (select uuid()), e.changed_by, e.date_changed, 14 from $OPDDATABASE.encounter_back e
inner join $OPDDATABASE.user_backup u ON e.creator = u.OPD_user_id
group by e.patient_id, e.encounter_id, e.encounter_type, DATE(e.encounter_datetime);

/* creating orders back-up */
drop table if exists $OPDDATABASE.orders_bak;

create table $OPDDATABASE.orders_bak as
SELECT order_id as OPD_order_id, (SELECT @max_order_id + o.order_id) as ART_order_id, order_type_id, concept_id, orderer, (SELECT @max_encounter_id + o.encounter_id) as encounter_id, instructions, start_date, auto_expire_date, discontinued, discontinued_date, discontinued_by, discontinued_reason, (SELECT @max_user_id + creator) as creator, date_created, voided, voided_by, date_voided, void_reason, e.ART_patient_id AS patient_id, accession_number, (SELECT @max_obs_id + o.obs_id) as obs_id, uuid, discontinued_reason_non_coded FROM $OPDDATABASE.orders o inner join $OPDDATABASE.opd_patient_details_in_art e on e.OPD_patient_id = o.patient_id WHERE o.voided = 0;

/* insert OPD orders into ART database */
INSERT INTO $DATABASE.orders (order_id,  order_type_id,  concept_id,  orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT o.ART_order_id, o.order_type_id, o.concept_id, o.orderer, o.encounter_id, o.instructions, o.start_date, o.auto_expire_date, o.discontinued,  o.discontinued_date, o.discontinued_by, o.discontinued_reason, u.ART_user_id, o.date_created, o.voided,  o.voided_by,  o.date_voided,  o.void_reason, o.patient_id, o.accession_number, o.obs_id,  (SELECT UUID()),  o.discontinued_reason_non_coded FROM $OPDDATABASE.orders_bak o inner join $OPDDATABASE.user_backup u ON o.creator = u.OPD_user_id
group by o.ART_order_id;

/* insert OPD drug_orders into ART database */
INSERT INTO $DATABASE.drug_order (order_id,  drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT o.ART_order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity 
FROM $OPDDATABASE.drug_order d
inner join $OPDDATABASE.orders_bak o on o.OPD_order_id = d.order_id GROUP BY o.OPD_order_id;

/* creating obs back-up */
drop table if exists $OPDDATABASE.obs_bak;

create table $OPDDATABASE.obs_bak as
SELECT o.obs_id as OPD_obs_id, (SELECT @max_obs_id + o.obs_id) as ART_obs_id, e.ART_patient_id AS person_id,  o.concept_id,  (SELECT @max_encounter_id + o.encounter_id) AS encounter_id, (SELECT @max_order_id + o.order_id) AS order_id,  o.obs_datetime,  o.location_id,  o.obs_group_id,  o.accession_number,  o.value_group_id, o.value_boolean, o.value_coded, o.value_coded_name_id, o.value_drug, o.value_datetime, o.value_numeric, o.value_modifier, o.value_text,  o.date_started, o.date_stopped, o.comments, u.ART_user_id AS creator,  o.date_created,  o.voided,  o.voided_by,  o.date_voided,  o.void_reason,  o.value_complex, o.uuid 
FROM $OPDDATABASE.obs o 
inner join $OPDDATABASE.opd_patient_details_in_art e on e.OPD_patient_id = o.person_id 
inner join $OPDDATABASE.user_backup u on u.OPD_user_id = o.creator
WHERE o.voided = 0 group by o.obs_id;
   
/* insert OPD obs into ART database */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT ART_obs_id, person_id,  concept_id, encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric, value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided, voided_by,  date_voided,  void_reason,  value_complex,  (SELECT UUID()) FROM $OPDDATABASE.obs_bak;

/* creating patient_program back-up */
drop table if exists $OPDDATABASE.patient_program_backup;

create table $OPDDATABASE.patient_program_backup as
SELECT patient_program_id AS OPD_patient_program_id, (SELECT @max_patient_program_id + patient_program_id) AS ART_patient_program_id, e.ART_patient_id AS patient_id,  p.program_id,  p.date_enrolled, p.date_completed, u.ART_user_id as creator, p.date_created, p.changed_by,  p.date_changed,  p.voided, p.voided_by, p.date_voided, p.void_reason, p.uuid, p.location_id 
FROM $OPDDATABASE.patient_program p 
INNER JOIN $OPDDATABASE.opd_patient_details_in_art e on e.OPD_patient_id = p.patient_id 
INNER JOIN $OPDDATABASE.user_backup u on u.OPD_user_id = p.creator GROUP BY p.patient_program_id;

/* insert OPD patient_program into ART database */ 
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
select ART_patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  changed_by,  voided, voided_by,  date_voided,  void_reason,  (SELECT UUID()),  location_id from $OPDDATABASE.patient_program_backup f order by patient_id;

/* insert OPD patient_state into ART database */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT p.ART_patient_program_id, f.state, f.start_date, f.end_date, p.creator, f.date_created, f.changed_by, f.date_changed, f.voided, f.voided_by, f.date_voided, f.void_reason, (SELECT UUID()) FROM  $OPDDATABASE.patient_state f
INNER JOIN $OPDDATABASE.patient_program_backup p on p.OPD_patient_program_id = f.patient_program_id
ORDER BY patient_program_id;

SET foreign_key_checks = 1;

EOF

echo "Migrating OPD patients that are only in OPD and not in ART"
./bin/OPD_scripts/opd_patients_not_in_art.sh development

echo "Migrating remaining OPD patients"
./bin/OPD_scripts/opd_remaining_patients.sh development

echo "Migrating OPD patients with multiple identifiers"
./bin/OPD_scripts/opd_patients_with_multiple_identifiers.sh development

echo "Finished merging the data"
