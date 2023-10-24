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

# if port is not set, use default port 3306
if [ -z "$PORT" ]; then
  PORT=3306
fi

mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/openmrs_metadata_1_7.sql

## We need to bypass some migrations that are causing errors
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/bypass_migrations.sql

rails db:migrate

mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/add_regimens_13_and_above.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/add_cpt_and_inh_to_regimen_ingredients.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/alternative_drug_names.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/fix_weight_and_height_obs.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/index_obs_value_datetime.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/moh_regimens_v2018.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/bart2_views_schema_additions.sql
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE < db/sql/ntp_regimens.sql


# now call the update_art_metadata.sh script
bin/update_art_metadata.sh $ENV

echo "Update program IDS"
mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD $DATABASE -e 'UPDATE encounter SET program_id = 31 WHERE program_id = 1 OR program_id IS NULL;'