#!/bin/bash

# we need to check for configuration files and create them if they don't exist
if [ ! -f config/database.yml ]; then
    cp config/database.yml.example config/database.yml

    # in config/database.yml replace 3308 with 3306
    sed -i 's/3308/3306/g' config/database.yml
    sed -i 's/your_scoped_username/root/g' config/database.yml
    sed -i 's/your_secret_password/root/g' config/database.yml
fi

# application.yml
if [ ! -f config/application.yml ]; then
    cp config/application.yml.example config/application.yml
fi

# ait.yml
if [ ! -f config/ait.yml ]; then
    cp config/ait.yml.example config/ait.yml
fi

# cable.yml
if [ ! -f config/cable.yml ]; then
    cp config/cable.yml.example config/cable.yml
fi

# storage.yml
if [ ! -f config/storage.yml ]; then
    cp config/storage.yml.example config/storage.yml
fi

if [ ! -f config/secrets.yml ]; then
    bash bin/setup_production_mode.sh
fi

rm Gemfile.lock

bundle install

# initialize the database
bin/initial_database_setup.sh production mpc
bin/initial_database_setup.sh development mpc
bin/initial_database_setup.sh test mpc
# update the art metadata
bin/update_art_metadata.sh production
bin/update_art_metadata.sh development

# handling dubious ownership
git config --global --add safe.directory /workspaces/BHT-EMR-API
