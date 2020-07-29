#!/bin/bash

BIN_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_PATH="`dirname $BIN_PATH`"

USERNAME=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('$ROOT_PATH/config/database.yml')['development']['host']"`


mysqldump -u $USERNAME --password=$PASSWORD --host=$HOST $DATABASE moh_regimens moh_regimen_doses moh_regimen_ingredient \
          moh_regimen_ingredient_starter_packs moh_regimen_lookup moh_regimen_ingredient_tb_treatment alternative_drug_names \
          moh_regimen_combination moh_regimen_combination_drug moh_regimen_name
