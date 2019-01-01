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

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/openmrs_metadata_1_7.sql

rails db:migrate

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/add_regimens_13_and_above.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/add_cpt_and_inh_to_regimen_ingredients.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/alternative_drug_names.sql