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

echo "================= Started reversing migration"

start_now=$(date +”%T”)
echo "the script is starting at: " $start_now

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE <<EOF

/* SET foreign_key_checks = 0; */
SELECT "saving patients that have visited after migrations";
DROP TABLE IF EXISTS $ANCDATABASE.ART_patient_in_use;

CREATE TABLE $ANCDATABASE.ART_patient_in_use AS
SELECT p.patient_id
FROM $DATABASE.patient p
INNER JOIN $DATABASE.encounter e ON p.patient_id = e.patient_id
WHERE p.creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) GROUP BY p.patient_id HAVING COUNT(*) > 1;

SELECT "saving patients identifiers that have visited after migrations";
DROP TABLE IF EXISTS $ANCDATABASE.ART_patient_identifier_in_use;

CREATE TABLE $ANCDATABASE.ART_patient_identifier_in_use AS
SELECT e.patient_id, e.identifier
FROM $DATABASE.patient_identifier e
WHERE e.patient_id IN (SELECT p.patient_id FROM $ANCDATABASE.ART_patient_in_use p);

ALTER TABLE $ANCDATABASE.ART_patient_identifier_in_use ADD INDEX identifier_in_use (patient_id);

SELECT "saving patient mapping";
DROP TABLE IF EXISTS $ANCDATABASE.patient_migration_mapping;

CREATE TABLE $ANCDATABASE.patient_migration_mapping
SELECT DISTINCT(anc.patient_id) AS anc_patient_id, art.patient_id AS art_patient_id
FROM $ANCDATABASE.patient_identifier anc
JOIN $DATABASE.patient_identifier art ON anc.identifier = art.identifier
JOIN $ANCDATABASE.user_bak bak ON anc.creator = bak.ANC_user_id
WHERE art.creator = bak.ART_user_id
AND art.date_created = anc.date_created;

ALTER TABLE $ANCDATABASE.patient_migration_mapping add primary key (anc_patient_id);

SELECT "saving patient identifiers for those not in use";
DROP TABLE IF EXISTS $ANCDATABASE.ART_patient_identifier_not_in_use;

CREATE TABLE $ANCDATABASE.ART_patient_identifier_not_in_use AS
SELECT e.patient_id, e.identifier
FROM $DATABASE.patient_identifier e
WHERE e.patient_id NOT IN (SELECT p.patient_id FROM $ANCDATABASE.ART_patient_in_use p)
AND e.patient_id IN (SELECT art_patient_id FROM $ANCDATABASE.patient_migration_mapping);

ALTER TABLE $ANCDATABASE.ART_patient_identifier_not_in_use ADD INDEX identifier_not_in_use (patient_id);

SELECT "removing drug_orders";
DELETE FROM $DATABASE.drug_order WHERE order_id IN (SELECT order_id FROM $DATABASE.orders WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use));

SELECT "removing orders";
DELETE FROM $DATABASE.orders WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing observations";
DELETE FROM $DATABASE.obs WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing encounters";
DELETE FROM $DATABASE.encounter WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing patient state";
DELETE FROM $DATABASE.patient_state WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_program_id NOT IN(SELECT patient_program_id FROM $DATABASE.patient_program WHERE patient_id IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use));

SELECT "removing patient program";
DELETE FROM $DATABASE.patient_program WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing patient identifier";
DELETE FROM $DATABASE.patient_identifier WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing patients";
DELETE FROM $DATABASE.patient WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND patient_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing person attribute";
DELETE FROM $DATABASE.person_attribute WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing person address";
DELETE FROM $DATABASE.person_address WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "removing person name";
DELETE FROM $DATABASE.person_name WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SET foreign_key_checks = 0;
SELECT "removing users";
DELETE FROM $DATABASE.users WHERE user_id IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND user_id NOT IN (SELECT DISTINCT(creator) FROM $DATABASE.patient);

SELECT "removing person";
DELETE FROM $DATABASE.person WHERE creator IN (SELECT ART_user_id FROM $ANCDATABASE.user_bak) AND person_id NOT IN (SELECT patient_id FROM $ANCDATABASE.ART_patient_in_use);

SELECT "complete running queries";

SET foreign_key_checks = 1;
EOF

echo "====================================================Finished reversing migration"

end_now=$(date +”%T”)

echo "the script started running at: " $start_now
echo "and ended at: " $end_now