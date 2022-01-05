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
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`
PORT=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['port']"`

# Only update metadata if migration is successful
rails db:migrate && {
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/openmrs_metadata_1_7.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/bart2_views_schema_additions.sql
  mysql --host=$HOST --port=$PORT --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/moh_regimens_v2020.sql
}

