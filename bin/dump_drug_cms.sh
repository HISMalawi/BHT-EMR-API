#!/bin/bash

BIN_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_PATH="`dirname $BIN_PATH`"

USERNAME=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['host']"`
PORT=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['port']"`

METADATA_FILE=${ROOT_PATH}/db/sql/drug_cms_metadata.sql

if [ -n `mysqldump --version | cut -d ' ' -f 4 | grep -P '8\.\d+\.\d+.*'` ]; then
  ARGS='--disable-column-statistics'
else
  ARGS=''
fi

set -x

mysqldump -u $USERNAME --password=$PASSWORD --host=$HOST --port=$PORT $ARGS $DATABASE drug_cms
