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

echo "merge ANC data into ART database"

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

SET foreign_key_checks = 0;
/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) from $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) from $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);
SET @max_user_id := (select max(user_id) from $DATABASE.users);

/* dropping and creating person_back_up  */
DROP table IF EXISTS $ANCDATABASE.ANC_only_patients_details;

create table  $ANCDATABASE.ANC_only_patients_details as
SELECT patient_id FROM $ANCDATABASE.patient_identifier WHERE identifier_type = 3 AND voided = 0 AND patient_id NOT IN (SELECT ANC_patient_id FROM $ANCDATABASE.ANC_patient_details) AND identifier NOT IN (SELECT identifier FROM $DATABASE.patient_identifier WHERE identifier in (SELECT identifier FROM $ANCDATABASE.patient_identifier WHERE patient_id NOT IN (SELECT ANC_patient_id FROM $ANCDATABASE.ANC_patient_details)));

/* The first query is inserting BDE person table into main person table minus the users  */  
INSERT INTO $DATABASE.person (person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
select (select @max_patient_id + pp.patient_id) as person_id, gender, birthdate, birthdate_estimated, dead, death_date, cause_of_death, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, (select uuid()) from $ANCDATABASE.person p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.person_id;

/* This query insert BDE person_name table into main person_name table minus the users  */ 
INSERT INTO $DATABASE.person_name (preferred, person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided, voided_by, date_voided, void_reason, changed_by, date_changed, uuid)
select preferred, (select @max_patient_id + pp.patient_id) as person_id, prefix, given_name, middle_name, family_name_prefix, family_name, family_name2, family_name_suffix, degree, creator, date_created, voided,  voided_by, date_voided, void_reason,  changed_by, date_changed, (select uuid())  from $ANCDATABASE.person_name p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.person_id;

/* This query insert BDE person_address into main person_address  */
INSERT INTO $DATABASE.person_address (person_id,  preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,  voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division,  uuid)
select (select @max_patient_id + pp.patient_id) as person_id, preferred,  address1,  address2,  city_village,  state_province,  postal_code,  country,  latitude,  longitude,  creator,  date_created,  voided,   voided_by,  date_voided, void_reason, county_district,  neighborhood_cell,  region,  subregion,  township_division, (select uuid()) from $ANCDATABASE.person_address p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.person_id;

/* This query insert BDE person_attributes into main person_attributes  */
INSERT INTO $DATABASE.person_attribute (person_id, value, person_attribute_type_id, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
select (select @max_patient_id + pp.patient_id) as person_id, value, person_attribute_type_id, creator, date_created,  changed_by, date_changed, voided,  voided_by, date_voided, void_reason, (select uuid()) from $ANCDATABASE.person_attribute p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.person_id;

/* This query insert BDE patient into main patient  */
INSERT INTO $DATABASE.patient (patient_id, tribe, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason)
select (select @max_patient_id + pp.patient_id) as patient_id, tribe, creator, date_created,   changed_by, date_changed, voided,  voided_by, date_voided, void_reason from $ANCDATABASE.patient p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.patient_id;

/* This query insert BDE patient_identifier into main patient_identifier  */ 
INSERT INTO $DATABASE.patient_identifier (patient_id,  identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  uuid)
select (select @max_patient_id + pp.patient_id) as patient_id, identifier,  identifier_type,  preferred,  location_id,  creator,  date_created,  voided,   voided_by,  date_voided,  void_reason, (select uuid()) from $ANCDATABASE.patient_identifier p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.patient_id;

/* This query back-up main encounter  */
drop table if exists $ANCDATABASE.encounter_bak_up;
create table  $ANCDATABASE.encounter_bak_up as
select (select @max_encounter_id + encounter_id) as encounter_id, encounter_type, (select @max_patient_id + pp.patient_id) as patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided,  voided_by, date_voided, void_reason, uuid, changed_by, date_changed from $ANCDATABASE.encounter e inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = e.patient_id;

/* This query insert BDE encounter into main encounter  */ 
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed)
select encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (select uuid()), changed_by, date_changed from $ANCDATABASE.encounter_bak_up;

/* This query back-ups patient_program table  */
drop table if exists $ANCDATABASE.patient_program_bakup;
create table  $ANCDATABASE.patient_program_bakup as
SELECT patient_program_id as anc_patient_program_id, (select @max_patient_program_id + patient_program_id) as patient_program_id, (select @max_patient_id + pp.patient_id) as patient_id, program_id,  date_enrolled,  date_completed,  creator,  date_created,  changed_by,  date_changed,  voided,  voided_by,  date_voided,  void_reason,  uuid,  location_id FROM $ANCDATABASE.patient_program p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.patient_id;

/* This query insert BDE patient_program into main patient_program  */ 
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
select patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,   changed_by,  voided,  voided_by,  date_voided,  void_reason,  (SELECT UUID()), location_id from $ANCDATABASE.patient_program_bakup ;

/* This query insert BDE patient_state into main patient_state */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT pp.patient_program_id as patient_program_id, ps.state, ps.start_date, ps.end_date, ps.creator, ps.date_created,  ps.changed_by, ps.date_changed, ps.voided,  ps.voided_by, ps.date_voided, ps.void_reason, (SELECT UUID()) FROM $ANCDATABASE.patient_state ps inner join $ANCDATABASE.patient_program_bakup pp on pp.anc_patient_program_id = ps.patient_program_id;

/* This query insert BDE orders into main orders */
INSERT INTO $DATABASE.orders (order_id, order_type_id, concept_id, orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason, creator, date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT (SELECT @max_order_id + order_id) as order_id,  order_type_id, concept_id, orderer, (SELECT @max_encounter_id + encounter_id) as encounter_id,  instructions, start_date, auto_expire_date,  discontinued,  discontinued_date, discontinued_by,  discontinued_reason,  creator,  date_created,  voided,   voided_by,  date_voided, void_reason, (SELECT @max_patient_id + pp.patient_id), accession_number, (SELECT @max_obs_id + obs_id), (SELECT UUID()), discontinued_reason_non_coded FROM $ANCDATABASE.orders p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.patient_id;

/* This query insert BDE drug_order into main drug_order */
INSERT INTO $DATABASE.drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT (SELECT @max_order_id + order_id) as order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity FROM $ANCDATABASE.drug_order;

/* This query insert BDE obs into main obs */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT (SELECT @max_obs_id + obs_id), (SELECT @max_patient_id + person_id),  concept_id,  (SELECT @max_encounter_id + encounter_id),  (SELECT @max_order_id + order_id),  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,   voided_by,  date_voided,  void_reason,  value_complex,  (SELECT UUID()) FROM $ANCDATABASE.obs  p inner join $ANCDATABASE.ANC_only_patients_details pp on pp.patient_id = p.person_id;

/*dropping the temporaly tables*/

drop table if exists $ANCDATABASE.encounter_bak_up;
drop table if exists $ANCDATABASE.patient_program_bakup;

SET foreign_key_checks = 1;

EOF

echo "Finished merging the data"
