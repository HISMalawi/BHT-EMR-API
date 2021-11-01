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

echo "=================migrating observation and drug_orders in ANC only into ART database"

start_now=$(date +”%T”)
echo "the script is starting at: " start_now

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

/* SET foreign_key_checks = 0; */
/* the defaults */
SET @max_encounter_id := COALESCE((SELECT max(encounter_id) FROM $DATABASE.encounter), 0);
SET @max_patient_id := COALESCE((SELECT max(person_id) FROM $DATABASE.person),0);
SET @max_patient_program_id := COALESCE((SELECT max(patient_program_id) from $DATABASE.patient_program),0);
SET @max_order_id := COALESCE((SELECT max(order_id) from $DATABASE.orders),0);
SET @max_obs_id := COALESCE((SELECT max(obs_id) FROM $DATABASE.obs),0);
SET @max_user_id := COALESCE((select max(user_id) from $DATABASE.users),0);

select "Preparing database for migration";

START TRANSACTION;
/* Creating patient mapping between the two database. */
DROP TABLE IF EXISTS $ANCDATABASE.patient_migration_mapping;
CREATE TABLE $ANCDATABASE.patient_migration_mapping(
anc_patient_id BIGINT NOT NULL,
art_patient_id BIGINT NOT NULL,
primary key(anc_patient_id)
);

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select ANC_patient_id, ART_patient_id from $ANCDATABASE.ANC_patient_details;

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select ANC_patient_id, ART_patient_id from $ANCDATABASE.ANC_only_patients_details;

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select ANC_patient_id, ART_patient_id from $ANCDATABASE.anc_remaining_diff_gender;

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select distinct(ANC_patient_id), ART_patient_id from $ANCDATABASE.anc_art_patients_with_voided_art_identifier e
where e.ANC_patient_id not in (select o.anc_patient_id from $ANCDATABASE.patient_migration_mapping o)
group by e.ANC_patient_id having count(*) = 1;

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select ANC_patient_id, ART_patient_id from $ANCDATABASE.ANC_last_patients_not_migrated;

insert into $ANCDATABASE.patient_migration_mapping(anc_patient_id, art_patient_id)
select ANC_patient_id, ART_patient_id from $ANCDATABASE.patients_remaining_to_be_migrated
where ANC_patient_id not in (select o.anc_patient_id from $ANCDATABASE.patient_migration_mapping o)
group by ANC_patient_id having count(*) = 1;

/* Drop them tables */
DROP TABLE IF EXISTS $ANCDATABASE.encounter_duplicate_id;
DROP TABLE IF EXISTS $ANCDATABASE.encounter_migration_mapping;
DROP TABLE IF EXISTS $ANCDATABASE.encounter_duplicate_migration_mapping;
DROP TABLE IF EXISTS $ANCDATABASE.order_duplicate_id;
DROP TABLE IF EXISTS $ANCDATABASE.order_migration_mapping;
DROP TABLE IF EXISTS $ANCDATABASE.order_duplicate_migration_mapping;
# DROP TABLE IF EXISTS $ANCDATABASE.obs_migration_mapping;


DROP TABLE IF EXISTS $ANCDATABASE.temp_patient_mapping;
CREATE TABLE $ANCDATABASE.temp_patient_mapping
SELECT map.anc_patient_id, map.art_patient_id
FROM $ANCDATABASE.ANC_patients_merged_into_main_dbs dbs
INNER JOIN $ANCDATABASE.patient_migration_mapping map ON dbs.ANC_patient_id = map.anc_patient_id;

CREATE TABLE IF NOT EXISTS $ANCDATABASE.encounter_duplicate_id(
anc_encounter_id BIGINT NOT NULL,
anc_patient_id BIGINT NOT NULL,
art_patient_id BIGINT NOT NULL,
anc_encounter_type INT NOT NULL,
art_encounter_type INT NOT NULL,
current_provider_id INT NOT NULL,
anc_provider_id INT NOT NULL,
anc_creator INT NOT NULL,
art_creator INT NOT NULL,
date_created DATETIME NOT NULL,
encounter_datetime DATETIME NOT NULL,
duplicate_num INT NOT NULL,
PRIMARY KEY (anc_encounter_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.encounter_migration_mapping(
anc_encounter_id BIGINT NOT NULL,
art_encounter_id BIGINT NOT NULL,
PRIMARY KEY (anc_encounter_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.encounter_duplicate_migration_mapping(
anc_encounter_id BIGINT NOT NULL,
art_encounter_id BIGINT NOT NULL,
PRIMARY KEY (anc_encounter_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.obs_migration_mapping(
anc_obs_id BIGINT NOT NULL,
art_obs_id BIGINT NOT NULL,
PRIMARY KEY (anc_obs_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.order_duplicate_id(
anc_order_id BIGINT NOT NULL,
anc_patient_id BIGINT NOT NULL,
art_patient_id BIGINT NOT NULL,
anc_creator BIGINT NOT NULL,
art_creator BIGINT NOT NULL,
date_created DATETIME NOT NULL,
start_date DATETIME NOT NULL,
concept_id INT NOT NULL,
order_type_id INT NOT NULL,
instructions TEXT NULL,
duplicate_num INT NOT NULL,
PRIMARY KEY (anc_order_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.order_migration_mapping(
anc_order_id BIGINT NOT NULL,
art_order_id BIGINT NOT NULL,
PRIMARY KEY (anc_order_id)
);

CREATE TABLE IF NOT EXISTS $ANCDATABASE.order_duplicate_migration_mapping(
anc_order_id BIGINT NOT NULL,
art_order_id BIGINT NOT NULL,
PRIMARY KEY (anc_order_id)
);

DROP PROCEDURE IF EXISTS $ANCDATABASE.duplicate_encounter_identifier;
DROP PROCEDURE IF EXISTS $ANCDATABASE.duplicate_encounter_mapper;
DROP PROCEDURE IF EXISTS $ANCDATABASE.duplicate_order_identifier;
DROP PROCEDURE IF EXISTS $ANCDATABASE.duplicate_order_mapper;

DELIMITER //
CREATE PROCEDURE $ANCDATABASE.duplicate_encounter_identifier()
BEGIN
	DECLARE finished INT DEFAULT 0;
	DECLARE cursor_patient_id BIGINT;
	DECLARE cursor_encounter_type INT;
	DECLARE cursor_provider_id INT;
	DECLARE cursor_creator INT;
	DECLARE cursor_date_created DATETIME;
	DECLARE cursor_encounter_datetime DATETIME;
    DECLARE duplicates CURSOR FOR
		SELECT patient_id, encounter_type, provider_id, creator, date_created, encounter_datetime
        FROM $ANCDATABASE.encounter
		WHERE voided = 0
        AND patient_id in (select wow.anc_patient_id from $ANCDATABASE.temp_patient_mapping wow)
		GROUP BY patient_id, encounter_type, provider_id, creator, date_created, encounter_datetime
		HAVING count(*) > 1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    OPEN duplicates;
    REPEAT
		FETCH duplicates
        INTO cursor_patient_id, cursor_encounter_type, cursor_provider_id, cursor_creator, cursor_date_created, cursor_encounter_datetime;
        IF NOT finished
        THEN
			SET @i = -1;
            INSERT INTO $ANCDATABASE.encounter_duplicate_id(anc_encounter_id, anc_patient_id, art_patient_id, anc_encounter_type, art_encounter_type, current_provider_id, anc_provider_id, anc_creator, art_creator, date_created, encounter_datetime, duplicate_num)
			SELECT
            e.encounter_id,
            e.patient_id,
            map.art_patient_id,
            e.encounter_type,
			if(e.encounter_type=61, 98, e.encounter_type),
            e.provider_id,
			if(e.provider_id = 0 or e.provider_id is null, e.creator, e.provider_id),
            e.creator,
			bak.ART_user_id,
			e.date_created,
			e.encounter_datetime,
			(@i:=@i+1)
			FROM $ANCDATABASE.encounter e
			INNER JOIN $ANCDATABASE.user_bak bak ON bak.ANC_user_id = e.creator
			INNER JOIN $ANCDATABASE.temp_patient_mapping map ON map.anc_patient_id = e.patient_id
			WHERE e.patient_id = cursor_patient_id
			AND e.encounter_type = cursor_encounter_type
			AND e.provider_id = cursor_provider_id
			AND e.creator = cursor_creator
			AND e.date_created = cursor_date_created
			AND e.encounter_datetime = cursor_encounter_datetime;
        END IF;
    UNTIL finished
	END REPEAT;

    CLOSE duplicates;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE $ANCDATABASE.duplicate_encounter_mapper()
BEGIN
	DECLARE finished INT DEFAULT 0;
    DECLARE cursor_encounter_id BIGINT;
	DECLARE cursor_patient_id BIGINT;
	DECLARE cursor_encounter_type INT;
	DECLARE cursor_provider_id INT;
	DECLARE cursor_creator INT;
	DECLARE cursor_date_created DATETIME;
	DECLARE cursor_encounter_datetime DATETIME;
    DECLARE cursor_duplicate_num INT;
    DECLARE duplicate_ids CURSOR FOR
		SELECT e.anc_encounter_id,e.art_patient_id, e.art_encounter_type, e.anc_provider_id, e.art_creator, e.date_created, e.encounter_datetime, e.duplicate_num
        FROM $ANCDATABASE.encounter_duplicate_id e;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    OPEN duplicate_ids;
    REPEAT
		FETCH duplicate_ids
        INTO cursor_encounter_id, cursor_patient_id, cursor_encounter_type, cursor_provider_id, cursor_creator, cursor_date_created, cursor_encounter_datetime, cursor_duplicate_num;
        IF NOT finished
        THEN
			SET @encounter_id = cursor_encounter_id;
            SET @patient_id = cursor_patient_id;
            SET @encounter_type = cursor_encounter_type;
            SET @provider_id = cursor_provider_id;
            SET @creator = cursor_creator;
            SET @date_created = cursor_date_created;
            SET @encounter_datetime = cursor_encounter_datetime;
            SET @duplicate_num = cursor_duplicate_num;
			PREPARE stmt FROM "
            INSERT INTO $ANCDATABASE.encounter_duplicate_migration_mapping(anc_encounter_id, art_encounter_id)
            SELECT ?, e.encounter_id
			FROM $DATABASE.encounter e
			WHERE e.patient_id = ?
			AND e.encounter_type = ?
			AND e.creator = ?
			AND e.date_created = ?
			AND e.encounter_DATETIME = ?
			LIMIT ?,1;";
			EXECUTE stmt USING @encounter_id, @patient_id, @encounter_type, @creator, @date_created, @encounter_datetime, @duplicate_num;
        END IF;
    UNTIL finished
	END REPEAT;

    CLOSE duplicate_ids;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE $ANCDATABASE.duplicate_order_identifier()
BEGIN
	DECLARE finished INT DEFAULT 0;
	DECLARE cursor_patient_id BIGINT;
	DECLARE cursor_order_type INT;
	DECLARE cursor_concept_id INT;
	DECLARE cursor_creator INT;
	DECLARE cursor_date_created DATETIME;
	DECLARE cursor_start_date DATETIME;
    DECLARE cursor_instructions TEXT;
    DECLARE duplicates CURSOR FOR
		SELECT patient_id, concept_id, date_created, start_date, order_type_id, instructions, creator
		FROM $ANCDATABASE.orders
        WHERE voided = 0
        AND patient_id in (select wow.anc_patient_id from $ANCDATABASE.temp_patient_mapping wow)
		GROUP BY patient_id, concept_id, date_created, start_date, order_type_id, instructions, creator, auto_expire_date
		HAVING count(*) > 1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    OPEN duplicates;
    REPEAT
		FETCH duplicates
        INTO cursor_patient_id, cursor_concept_id, cursor_date_created, cursor_start_date, cursor_order_type, cursor_instructions, cursor_creator;
        IF NOT finished
        THEN
			SET @i = -1;
            INSERT INTO $ANCDATABASE.order_duplicate_id(anc_order_id, anc_patient_id, art_patient_id, anc_creator, art_creator, date_created, start_date, concept_id, order_type_id, instructions, duplicate_num)
			SELECT
            e.order_id,
            e.patient_id,
            map.art_patient_id,
            e.creator,
            bak.ART_user_id,
            e.date_created,
            e.start_date,
            e.concept_id,
            e.order_type_id,
            e.instructions,
			(@i:=@i+1)
			FROM $ANCDATABASE.orders e
			INNER JOIN $ANCDATABASE.user_bak bak ON bak.ANC_user_id = e.creator
			INNER JOIN $ANCDATABASE.temp_patient_mapping map ON map.anc_patient_id = e.patient_id
			WHERE e.patient_id = cursor_patient_id
			AND e.order_type_id = cursor_order_type
			AND e.concept_id = cursor_concept_id
			AND e.creator = cursor_creator
			AND e.date_created = cursor_date_created
			AND e.start_date = cursor_start_date
			AND e.instructions = cursor_instructions
            AND e.voided = 0;
        END IF;
    UNTIL finished
	END REPEAT;

    CLOSE duplicates;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE $ANCDATABASE.duplicate_order_mapper()
BEGIN
	DECLARE finished INT DEFAULT 0;
    DECLARE cursor_order_id BIGINT;
	DECLARE cursor_patient_id BIGINT;
	DECLARE cursor_order_type INT;
	DECLARE cursor_concept_id INT;
	DECLARE cursor_creator INT;
	DECLARE cursor_date_created DATETIME;
	DECLARE cursor_start_date DATETIME;
	DECLARE cursor_instructions TEXT;
    DECLARE cursor_duplicate_num INT;
    DECLARE duplicate_ids CURSOR FOR
		SELECT e.anc_order_id,e.art_patient_id, e.order_type_id, e.concept_id, e.art_creator, e.date_created, e.start_date, e.instructions, e.duplicate_num
        FROM $ANCDATABASE.order_duplicate_id e;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    OPEN duplicate_ids;
    REPEAT
		FETCH duplicate_ids
        INTO cursor_order_id, cursor_patient_id, cursor_order_type, cursor_concept_id, cursor_creator, cursor_date_created, cursor_start_date, cursor_instructions, cursor_duplicate_num;
        IF NOT finished
        THEN
			SET @order_id = cursor_order_id;
            SET @patient_id = cursor_patient_id;
            SET @order_type = cursor_order_type;
            SET @concept_id = cursor_concept_id;
            SET @creator = cursor_creator;
            SET @date_created = cursor_date_created;
            SET @start_date = cursor_start_date;
            SET @instructions = cursor_instructions;
            SET @duplicate_num = cursor_duplicate_num;
			PREPARE stmt FROM "
            INSERT INTO $ANCDATABASE.order_duplicate_migration_mapping(anc_order_id, art_order_id)
            SELECT ?, e.order_id
			FROM $DATABASE.orders e
			WHERE e.patient_id = ?
			AND e.order_type_id = ?
			AND e.creator = ?
			AND e.date_created = ?
			AND e.start_date = ?
            AND e.concept_id = ?
            AND e.instructions = ?
			LIMIT ?,1;";
			EXECUTE stmt USING @order_id, @patient_id, @order_type, @creator, @date_created, @start_date, @concept_id, @instructions, @duplicate_num;
        END IF;
    UNTIL finished
	END REPEAT;

    CLOSE duplicate_ids;
END //
DELIMITER ;

/* make call of identifier and mappers here */
call $ANCDATABASE.duplicate_encounter_identifier();
call $ANCDATABASE.duplicate_encounter_mapper();

/* Map the remaining here */

INSERT INTO $ANCDATABASE.encounter_migration_mapping(anc_encounter_id, art_encounter_id)
SELECT e.encounter_id AS anc_encounter_id,
(SELECT art_e.encounter_id
FROM $DATABASE.encounter art_e
WHERE art_e.patient_id = map.art_patient_id
AND art_e.encounter_type = IF(e.encounter_type=61, 98, e.encounter_type)
AND art_e.date_created = e.date_created
AND art_e.encounter_datetime = e.encounter_datetime
AND art_e.creator = bak.ART_user_id
AND art_e.encounter_id NOT IN (SELECT art_encounter_id FROM $ANCDATABASE.encounter_duplicate_migration_mapping)) AS art_encounter_id
FROM $ANCDATABASE.encounter e
INNER JOIN $ANCDATABASE.temp_patient_mapping map ON map.anc_patient_id = e.patient_id
INNER JOIN $ANCDATABASE.user_bak bak ON e.creator = bak.ANC_user_id
WHERE e.voided = 0
AND e.patient_id IN (SELECT wow.anc_patient_id FROM $ANCDATABASE.temp_patient_mapping wow)
AND e.encounter_id NOT IN (SELECT anc_encounter_id FROM $ANCDATABASE.encounter_duplicate_migration_mapping);


INSERT INTO $ANCDATABASE.encounter_migration_mapping(anc_encounter_id, art_encounter_id)
select anc_encounter_id, art_encounter_id from $ANCDATABASE.encounter_duplicate_migration_mapping;

/* make call of identifier and mappers here */
call $ANCDATABASE.duplicate_order_identifier();
call $ANCDATABASE.duplicate_order_mapper();


/* Map the remaining here */
INSERT INTO $ANCDATABASE.order_migration_mapping(anc_order_id, art_order_id)
SELECT e.order_id,
(SELECT art_e.order_id
FROM $DATABASE.orders art_e
WHERE art_e.patient_id = map.art_patient_id
AND art_e.order_type_id = e.order_type_id
AND art_e.date_created = e.date_created
AND art_e.start_date = e.start_date
AND art_e.creator = bak.ART_user_id
AND art_e.instructions = e.instructions
AND art_e.concept_id = e.concept_id
AND art_e.order_id NOT IN (SELECT art_order_id FROM $ANCDATABASE.order_duplicate_migration_mapping))
FROM $ANCDATABASE.orders e
INNER JOIN $ANCDATABASE.temp_patient_mapping map ON map.anc_patient_id = e.patient_id
INNER JOIN $ANCDATABASE.user_bak bak ON e.creator = bak.ANC_user_id
WHERE e.voided = 0
AND e.patient_id IN (SELECT wow.anc_patient_id FROM $ANCDATABASE.temp_patient_mapping wow)
and e.order_id NOT IN (SELECT anc_order_id FROM $ANCDATABASE.order_duplicate_migration_mapping);


INSERT INTO $ANCDATABASE.order_migration_mapping(anc_order_id, art_order_id)
select anc_order_id, art_order_id from $ANCDATABASE.order_duplicate_migration_mapping;

select "Starting the migration";

# select "Migrating remaining encounters";
# INSERT INTO $DATABASE.encounter (encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, uuid, changed_by, date_changed, program_id)
# select encounter_id, encounter_type, patient_id, provider_id, location_id, form_id, encounter_datetime, creator, date_created, voided, voided_by, date_voided, void_reason, (select uuid()), changed_by, date_changed, 12
# FROM $ANCDATABASE.encounter e
# INNER JOIN $ANCDATABASE.encounter_migration_mapping map ON e.encounter_id = map.anc_encounter_id

# WHERE map.art_encounter_id = 0
# order by patient_id;

/* This query insert BDE obs into main obs */
INSERT INTO $DATABASE.obs (obs_id, person_id,  concept_id,  encounter_id,  order_id,  obs_datetime,  location_id,  obs_group_id,  accession_number,  value_group_id,  value_boolean,  value_coded,  value_coded_name_id,  value_drug,  value_datetime,  value_numeric,  value_modifier,  value_text,  date_started,  date_stopped,  comments,  creator,  date_created,  voided,  voided_by,  date_voided,  void_reason,  value_complex,  uuid)
SELECT (SELECT @max_obs_id + obs_id) as obs_id,
pmap.art_patient_id,
p.concept_id,
emap.art_encounter_id,
p.order_id,
p.obs_datetime,
p.location_id,
p.obs_group_id,
p.accession_number,
p.value_group_id,
p.value_boolean,
p.value_coded,
p.value_coded_name_id,
p.value_drug,
p.value_datetime,
p.value_numeric,
p.value_modifier,
p.value_text,
p.date_started,
p.date_stopped,
p.comments,
cr.ART_user_id,
p.date_created,
p.voided,
p.voided_by,
p.date_voided,
p.void_reason,
p.value_complex,
(SELECT UUID())
FROM $ANCDATABASE.obs  p
JOIN $ANCDATABASE.patient_migration_mapping pmap ON p.person_id = pmap.anc_patient_id
JOIN $ANCDATABASE.encounter_migration_mapping emap ON p.encounter_id = emap.anc_encounter_id
JOIN $ANCDATABASE.user_bak cr ON cr.ANC_user_id = p.creator
WHERE p.voided = 0
AND emap.art_encounter_id != 0
AND p.obs_id NOT IN (SELECT anc_obs_id FROM $ANCDATABASE.obs_migration_mapping);


INSERT INTO $ANCDATABASE.obs_migration_mapping(anc_obs_id, art_obs_id)
select obs_id, (SELECT @max_obs_id + obs_id) as anc_obs_id FROM $ANCDATABASE.obs p
INNER JOIN $ANCDATABASE.encounter_migration_mapping emap ON p.encounter_id = emap.anc_encounter_id
WHERE emap.art_encounter_id != 0 and
p.obs_id NOT IN (SELECT anc_obs_id FROM $ANCDATABASE.obs_migration_mapping);


/* insert ANC drug_orders into ART database */
INSERT INTO $DATABASE.drug_order (order_id,  drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity)
SELECT art_order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, prn, complex, quantity
FROM $ANCDATABASE.drug_order d
INNER JOIN $ANCDATABASE.order_migration_mapping o on o.anc_order_id = d.order_id
WHERE o.art_order_id NOT IN (SELECT order_id from $DATABASE.drug_order);


select "Finished migrating data and creating associated mapping";
select "UPDATE Observications value_text, value_coded_name_id and value_coded in BOTH $ANCDATABASE and $DATABASE";

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

/* SET foreign_key_checks = 1; */

COMMIT;

EOF

echo "====================================================Finished migrating data"

end_now=$(date +”%T”)

echo "the script started running at: " $start_now
echo "and ended at: " $end_now

