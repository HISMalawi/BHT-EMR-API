#!/bin/bash

BIN_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_PATH="`dirname $BIN_PATH`"

USERNAME=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['host']"`
PORT=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['port']"`

# if port is not set, use default port 3306
if [ -z "$PORT" ]; then
  PORT=3306
fi

METADATA_FILE=${ROOT_PATH}/db/sql/openmrs_metadata_1_7.sql

if [ -n `mysqldump --version | cut -d ' ' -f 4 | grep -P '8\.\d+\.\d+.*'` ]; then
  ARGS='--disable-column-statistics'
else
  ARGS=''
fi

set -x

mysqldump -u $USERNAME --password=$PASSWORD --host=$HOST $ARGS $DATABASE \
  concept concept_name concept_set concept_answer concept_class concept_datatype \
  concept_derived concept_description concept_map concept_name_tag concept_name_tag_map \
  concept_numeric concept_proposal concept_proposal_tag_map concept_set_derived concept_source \
  concept_state_conversion concept_synonym concept_word encounter_type patient_identifier_type \
  order_type person_attribute_type program program_workflow program_workflow_state \
  relationship_type drug privilege location role
