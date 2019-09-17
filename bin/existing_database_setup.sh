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
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/fix_weight_and_height_obs.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/index_obs_value_datetime.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/moh_regimens_v2018.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/bart2_views_schema_additions.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/sql/ntp_regimens.sql

echo "Update program IDS"
