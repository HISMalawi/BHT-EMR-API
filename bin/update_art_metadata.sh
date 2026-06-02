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
export DISABLE_SPRING=1
rails db:environment:set RAILS_ENV=$ENV

whenever --update-crontab

USERNAME=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['host']"`
PORT=`ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']['port']"`

# Only update metadata if migration is successful
rails db:migrate && {
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/sql/openmrs_metadata_1_7.sql
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/sql/bart2_views_schema_additions.sql
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/initial_setup/anc2_schema_additions.sql
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/sql/moh_regimens_v2025.sql
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/sql/drug_cms_metadata.sql
  MYSQL_PWD=$PASSWORD mysql --host=$HOST --port=$PORT --user=$USERNAME $DATABASE < db/sql/ntp_regimens.sql
}

