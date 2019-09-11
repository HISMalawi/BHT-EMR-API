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

echo "migration patients with multiple identifiers"

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

SET foreign_key_checks = 0;
/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) FROM $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) FROM $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);
SET @max_user_id := (SELECT max(user_id) FROM $DATABASE.users);

/* dropping and creating person_back_up */
DROP TABLE IF EXISTS $OPDDATABASE.opd_duplicate_patients;

CREATE TABLE $OPDDATABASE.opd_duplicate_patients AS
select patient_id AS OPD_person_id, (SELECT @max_patient_id + patient_id) AS ART_person_id from $OPDDATABASE.opd_patients_with_multiple_identifier;

/* The first query is inserting BDE person table into main person table minus the users */
INSERT INTO $DATABASE.person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT pp.ART_person_id, p.gender, p.birthdate, p.birthdate_estimated, p.dead, p.death_date, p.cause_of_death, c.ART_user_id, p.date_created, c.ART_user_id, p.date_changed, p.voided, p.voided_by, p.date_voided, p.void_reason, (SELECT uuid()) 
FROM $OPDDATABASE.person p 
 INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.person_id AND p.voided = 0
 INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator GROUP BY p.person_id;

/* This query insert BDE person_name table into main person_name table minus the users */
INSERT INTO $DATABASE.person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
SELECT p.preferred, pp.ART_person_id, p.prefix, p.given_name, p.middle_name, p.family_name_prefix, p.family_name, p.family_name2, p.family_name_suffix, p.degree, c.ART_user_id, p.date_created, p.voided,  p.voided_by, p.date_voided, p.void_reason,  c.ART_user_id, p.date_changed, (SELECT uuid())
FROM $OPDDATABASE.person_name p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.person_id AND p.voided  = 0
  INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator GROUP BY p.person_id;

/* This query insert BDE person_address into main person_address */
INSERT INTO $DATABASE.person_address (person_id,  preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,  voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division,  uuid)
SELECT pp.ART_person_id, p.preferred,  p.address1,  p.address2,  p.city_village,  p.state_province, p.postal_code,  p.country,  p.latitude,  p.longitude,  c.ART_user_id,  p.date_created,  p.voided,  p.voided_by, p.date_voided, p.void_reason, p.county_district,  p.neighborhood_cell,  p.region,  p.subregion,  p.township_division, (SELECT uuid())
FROM $OPDDATABASE.person_address p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.person_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator GROUP BY p.person_id;

/* This query insert BDE person_attributes into main person_attributes */ 
INSERT INTO $DATABASE.person_attribute (person_id, value, person_attribute_type_id, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT pp.ART_person_id, p.value, p.person_attribute_type_id, c.ART_user_id, p.date_created,  c.ART_user_id, p.date_changed, p.voided,  p.voided_by, p.date_voided, p.void_reason, (SELECT uuid()) 
FROM $OPDDATABASE.person_attribute p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.person_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator;

/* This query insert BDE patient into main patient */
INSERT INTO $DATABASE.patient (patient_id, tribe, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason)
SELECT pp.ART_person_id, p.tribe, c.ART_user_id, p.date_created,  c.ART_user_id, p.date_changed, p.voided,  p.voided_by, p.date_voided, p.void_reason 
FROM $OPDDATABASE.patient p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.patient_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator GROUP BY ART_person_id;

/* This query insert BDE patient_identifier into main patient_identifier */  
INSERT INTO $DATABASE.patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  uuid)
SELECT pp.ART_person_id, p.identifier, 2,  p.preferred,  p.location_id,  c.ART_user_id,  p.date_created,  p.voided,  p.voided_by, p.date_voided, p.void_reason, (SELECT uuid()) 
FROM $OPDDATABASE.patient_identifier p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.patient_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c ON c.OPD_user_id = p.creator
  GROUP BY identifier, ART_person_id, identifier_type, DATE(p.date_created);

/* This query back-up main encounter */
DROP TABLE IF EXISTS $OPDDATABASE.encounter_bak_up;
CREATE TABLE $OPDDATABASE.encounter_bak_up as
SELECT (SELECT @max_encounter_id + e.encounter_id) as encounter_id, e.encounter_type, pp.ART_person_id as patient_id, c.ART_user_id AS provider_id, e.location_id, e.form_id, e.encounter_datetime, c.ART_user_id AS creator, e.date_created, e.voided, e.voided_by, e.date_voided, e.void_reason, e.uuid, e.changed_by, e.date_changed
FROM $OPDDATABASE.encounter e 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = e.patient_id and e.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c on c.OPD_user_id = e.creator
group by e.patient_id, e.encounter_id, e.encounter_type, DATE(e.encounter_datetime);

/* This query insert BDE encounter into main encounter */  
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
SELECT encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (SELECT uuid()), changed_by, date_changed, 14 FROM $OPDDATABASE.encounter_bak_up;

/* This query back-ups patient_program table */
DROP TABLE IF EXISTS $OPDDATABASE.patient_program_bakup;
CREATE TABLE  $OPDDATABASE.patient_program_bakup as
SELECT patient_program_id as OPD_patient_program_id, (SELECT @max_patient_program_id + patient_program_id) as patient_program_id, pp.ART_person_id as patient_id, program_id,  date_enrolled,  date_completed,  c.ART_user_id as creator, p.date_created, c.ART_user_id as changed_by, p.date_changed,  p.voided,  p.voided_by,  p.date_voided,  p.void_reason,  p.uuid,  location_id 
FROM $OPDDATABASE.patient_program p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.patient_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c on c.OPD_user_id = p.creator
GROUP BY patient_program_id;

/* This query insert BDE patient_program into main patient_program */
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by, date_voided, void_reason, uuid, location_id)
SELECT patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,   changed_by,  voided,  voided_by,  date_voided,  void_reason,  (SELECT UUID()), location_id FROM $OPDDATABASE.patient_program_bakup;

/* This query insert BDE patient_state into main patient_state */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT pp.patient_program_id as patient_program_id, ps.state, ps.start_date, ps.end_date, c.ART_user_id, ps.date_created,  c.ART_user_id, ps.date_changed, ps.voided,  ps.voided_by, ps.date_voided, ps.void_reason, (SELECT UUID()) 
FROM $OPDDATABASE.patient_state ps 
  INNER JOIN $OPDDATABASE.patient_program_bakup pp on pp.OPD_patient_program_id = ps.patient_program_id
  INNER JOIN $OPDDATABASE.user_backup c on c.OPD_user_id = ps.creator;

/* This query insert BDE orders into main orders */
DROP TABLE IF EXISTS $OPDDATABASE.orders_bak;

CREATE TABLE $OPDDATABASE.orders_bak as
SELECT order_id AS OPD_order_id,(SELECT @max_order_id + order_id) as ART_order_id, order_type_id, concept_id, orderer, (SELECT @max_encounter_id + encounter_id) as encounter_id, instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, c.ART_user_id as creator, p.date_created,  p.voided,  p.voided_by,  p.date_voided,  p.void_reason, pp.ART_person_id as patient_id,  accession_number, (SELECT @max_obs_id + obs_id) as obs_id,  p.uuid, discontinued_reason_non_coded 
FROM $OPDDATABASE.orders p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.patient_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c on c.OPD_user_id = p.creator GROUP BY order_id;

INSERT INTO $DATABASE.orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT ART_order_id,  order_type_id, concept_id, orderer, encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason,  creator,  date_created,  voided,   voided_by,  date_voided, void_reason, patient_id, accession_number, obs_id, (SELECT UUID()), discontinued_reason_non_coded FROM $OPDDATABASE.orders_bak;

/* This query insert BDE drug_order into main drug_order */ 
INSERT INTO $DATABASE.drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT ob.ART_order_id, dr.drug_inventory_id, dr.dose, dr.equivalent_daily_dose, dr.units, dr.frequency, dr.prn, dr.complex, dr.quantity 
FROM $OPDDATABASE.drug_order dr 
  INNER JOIN $OPDDATABASE.orders_bak ob on dr.order_id = ob.OPD_order_id GROUP BY ob.ART_order_id;

/* This query insert BDE obs into main obs */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT (SELECT @max_obs_id + obs_id) as obs_id, pp.ART_person_id,  concept_id,  (SELECT @max_encounter_id + encounter_id) as encounter_id,  (SELECT @max_order_id + order_id) as order_id, p.obs_datetime, p.location_id, p.obs_group_id, p.accession_number, p.value_group_id, p.value_boolean, p.value_coded, p.value_coded_name_id, p.value_drug, p.value_datetime, p.value_numeric, p.value_modifier, p.value_text, p.date_started, p.date_stopped,  p.comments, c.ART_user_id, p.date_created, p.voided, p.voided_by, p.date_voided, p.void_reason, p.value_complex,  (SELECT UUID()) 
FROM $OPDDATABASE.obs  p 
  INNER JOIN $OPDDATABASE.opd_duplicate_patients pp ON pp.OPD_person_id = p.person_id AND p.voided = 0
  INNER JOIN $OPDDATABASE.user_backup c on c.OPD_user_id = p.creator
GROUP BY obs_id;


EOF

echo "finished migration patients with multiple identifiers"
