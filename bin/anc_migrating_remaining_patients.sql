SET foreign_key_checks = 0;

/* the defaults */
SET @max_encounter_id := (SELECT max(encounter_id) FROM $DATABASE.encounter);
SET @max_patient_id := (SELECT max(person_id) FROM $DATABASE.person);
SET @max_patient_program_id := (SELECT max(patient_program_id) from $DATABASE.patient_program);
SET @max_order_id := (SELECT max(order_id) from $DATABASE.orders);
SET @max_obs_id := (SELECT max(obs_id) FROM $DATABASE.obs);

DROP TABLE if exists $ANCDATABASE.ANC_patients_merged_into_main_dbs;

CREATE TABLE $ANCDATABASE.ANC_patients_merged_into_main_dbs as 
SELECT ANC_patient_id FROM $ANCDATABASE.ANC_patient_details
UNION
SELECT ANC_patient_id FROM $ANCDATABASE.ANC_only_patients_details;

/* get the user ids*/
drop table if exists $ANCDATABASE.anc_remaining_patient;

create table $ANCDATABASE.anc_remaining_patient as
select pi.patient_id, pn.family_name, pn.given_name, pi.identifier, p.gender, p.birthdate from $ANCDATABASE.patient_identifier pi
 inner join $ANCDATABASE.person_name pn on pn.person_id = pi.patient_id
 inner join $ANCDATABASE.person p on p.person_id = pi.patient_id
where pi.identifier_type = 3 and pi.voided = 0 and pi.patient_id not in (select ANC_patient_id from $ANCDATABASE.ANC_patients_merged_into_main_dbs);

/*Get all patients that differ only gender */
drop table if exists $ANCDATABASE.anc_remaining_diff_gender;

create table $ANCDATABASE.anc_remaining_diff_gender as
select a.patient_id AS ANC_patient_id, a.given_name, a.family_name, a.identifier, pa.person_id as ART_patient_id, pa.birthdate, pa.gender
FROM $ANCDATABASE.anc_remaining_patient a 
 inner join $DATABASE.patient_identifier p on a.identifier = p.identifier and p.voided = 0
 inner join $DATABASE.person pa on pa.birthdate = a.birthdate and pa.voided = 0
 inner join $DATABASE.person_name pn on pn.person_id = pa.person_id
where pn.given_name = a.given_name and pn.family_name = a.family_name
Group by a.patient_id, pa.birthdate, p.identifier, a.given_name, a.family_name;

/* creating encounters table back-up  */
drop table if exists $ANCDATABASE.encounter_back;

create table $ANCDATABASE.encounter_back as
SELECT (SELECT @max_encounter_id + e.encounter_id) as encounter_id, e.encounter_type, a.ART_patient_id AS patient_id, provider_id, e.location_id, e.form_id, e.encounter_datetime, creator, e.date_created, e.voided, voided_by, e.date_voided, e.void_reason, e.uuid, changed_by, e.date_changed FROM $ANCDATABASE.anc_remaining_diff_gender a INNER JOIN $ANCDATABASE.encounter e ON e.patient_id = a.ANC_patient_id and e.voided = 0;

/* insert ANC encounters into ART database  */
INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
select encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (select uuid()), changed_by, date_changed, 12 from $ANCDATABASE.encounter_back order by patient_id;

/* creating orders back-up  */
drop table if exists $ANCDATABASE.orders_bak;

create table $ANCDATABASE.orders_bak as
SELECT (SELECT @max_order_id + o.order_id) as ART_order_id, order_id as ANC_order_id, order_type_id, concept_id, orderer, (SELECT @max_encounter_id + o.encounter_id) as encounter_id, instructions, start_date, auto_expire_date, discontinued, discontinued_date, discontinued_by, discontinued_reason, creator, date_created, voided, voided_by, date_voided, void_reason, e.ART_patient_id AS patient_id, accession_number, (SELECT @max_obs_id + o.obs_id) as obs_id, uuid, discontinued_reason_non_coded FROM $ANCDATABASE.orders o inner join $ANCDATABASE.anc_remaining_diff_gender e on e.ANC_patient_id = o.patient_id and o.voided = 0;

/* insert ANC orders into ART database  */
INSERT INTO $DATABASE.orders (order_id,  order_type_id,  concept_id,  orderer,  encounter_id,  instructions,  start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id,  accession_number, obs_id,  uuid, discontinued_reason_non_coded)
SELECT ART_order_id,  order_type_id,  concept_id,  orderer, encounter_id,  instructions, start_date,  auto_expire_date,  discontinued,  discontinued_date,  discontinued_by,  discontinued_reason,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, patient_id, accession_number, obs_id, (SELECT UUID()),  discontinued_reason_non_coded FROM $ANCDATABASE.orders_bak;

/* insert ANC drug_orders into ART database */
INSERT INTO $DATABASE.drug_order (order_id,  drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT ART_order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity FROM $ANCDATABASE.drug_order d inner join $ANCDATABASE.orders_bak o on o.ANC_order_id = d.order_id; 

/* creating obs back-up */
drop table if exists $ANCDATABASE.obs_bak;

create table $ANCDATABASE.obs_bak as
SELECT (SELECT @max_obs_id + o.obs_id) as obs_id, e.ART_patient_id AS person_id,  concept_id,  (SELECT @max_encounter_id + o.encounter_id) AS encounter_id,  (SELECT @max_order_id + o.order_id) AS order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments, creator,  date_created,  voided,  voided_by,  date_voided,  void_reason, value_complex,  uuid FROM $ANCDATABASE.obs o inner join $ANCDATABASE.anc_remaining_diff_gender e on e.ANC_patient_id = o.person_id and o.voided = 0;
   
/* insert ANC obs into ART database */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT obs_id, person_id,  concept_id, encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric, value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided, voided_by,  date_voided,  void_reason,  value_complex,  (SELECT UUID()) FROM $ANCDATABASE.obs_bak ORDER BY obs_id;

/* creating patient_program back-up */
drop table if exists $ANCDATABASE.patient_program_bak;

create table $ANCDATABASE.patient_program_bak as
SELECT (SELECT @max_patient_program_id + patient_program_id) AS patient_program_id, e.ART_patient_id AS patient_id, program_id, date_enrolled, date_completed, creator, date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id FROM $ANCDATABASE.patient_program p INNER JOIN $ANCDATABASE.anc_remaining_diff_gender e on e.ANC_patient_id = p.patient_id and p.voided = 0;

/* insert ANC patient_program into ART database */
INSERT INTO $DATABASE.patient_program (patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  date_changed,  voided, voided_by,  date_voided,  void_reason,  uuid,  location_id)
select patient_program_id,  patient_id,  program_id,  date_enrolled,  date_completed,  creator,  date_created, changed_by,  changed_by,  voided, voided_by,  date_voided,  void_reason,  (SELECT UUID()),  location_id from $ANCDATABASE.patient_program_bak f order by patient_id;

/* insert ANC patient_state into ART database */
INSERT INTO $DATABASE.patient_state (patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, uuid)
SELECT (SELECT @max_patient_program_id + patient_program_id) as patient_program_id, state, start_date, end_date, creator, date_created, changed_by, date_changed, voided, voided_by, date_voided, void_reason, (SELECT UUID()) FROM $ANCDATABASE.patient_state f ORDER BY patient_program_id;

/* update patient gender to 'F'*/
UPDATE $DATABASE.person SET gender = 'F' WHERE person_id IN (SELECT ART_patient_id FROM $ANCDATABASE.anc_remaining_diff_gender);

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

