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

whenever --update-crontab

read_config_value() {
  ruby -ryaml -e "
    cfg = YAML.safe_load(File.read('config/database.yml'), aliases: true)['${ENV}']
    cfg = cfg['primary'] if cfg && cfg['primary']
    puts cfg && cfg['$1']
  "
}

USERNAME=`read_config_value username`
PASSWORD=`read_config_value password`
DATABASE=`read_config_value database`
HOST=`read_config_value host`
PORT=`read_config_value port`

# Only update metadata if migration is successful
rails db:migrate && {
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/openmrs_metadata_1_7.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/bart2_views_schema_additions.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/anc2_schema_additions.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/moh_regimens_v2025.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/drug_cms_metadata.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/ntp_regimens.sql
}

