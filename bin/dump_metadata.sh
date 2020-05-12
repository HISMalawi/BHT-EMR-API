#!/bin/bash

BIN_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_PATH="`dirname $BIN_PATH`"

USERNAME=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['host']"`

METADATA_FILE=${ROOT_PATH}/db/sql/openmrs_metadata_1_7.sql

if [ -f $METADATA_FILE ]; then
  mysqldump -u $USERNAME --password=$PASSWORD --host=$HOST $DATABASE $(cat $METADATA_FILE | awk '/CREATE TABLE .*/ { gsub(/`/, "", $3); print $3 }')
else
  echo "No metadata file present: $METADATA_FILE"
  exit 255
fi
