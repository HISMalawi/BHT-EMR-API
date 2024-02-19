#!/bin/bash

source ~/.bashrc

rm Gemfile.lock

bundle install

# initialize the database
bin/initial_database_setup.sh production mpc
bin/initial_database_setup.sh development mpc
bin/initial_database_setup.sh test mpc
# update the art metadata
bin/update_art_metadata.sh production
bin/update_art_metadata.sh development