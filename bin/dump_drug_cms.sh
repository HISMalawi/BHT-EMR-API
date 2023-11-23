#!/bin/bash

BIN_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_PATH="`dirname $BIN_PATH`"

USERNAME=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['host']"`

METADATA_FILE=${ROOT_PATH}/db/sql/drug_cms_metadata.sql

if [ -n `mysqldump --version | cut -d ' ' -f 4 | grep -P '8\.\d+\.\d+.*'` ]; then
  ARGS='--disable-column-statistics'
else
  ARGS=''
fi

set -x

mysqldump -u $USERNAME --password=$PASSWORD --host=$HOST $ARGS $DATABASE drug_cms
