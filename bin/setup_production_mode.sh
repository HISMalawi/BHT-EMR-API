#!/bin/bash

# check if config folder has secret.yml
if [ ! -f config/secrets.yml ]; then
    echo "config/secrets.yml not found. Now creating one."
    cp config/secrets.yml.example config/secrets.yml
    # add secret key base to secrets.yml
    echo "Adding secret key base to secrets.yml"
    # generate secret key base and store it in a variable
    secret_key_base=$(rake secret)
    # replace the secret key base in secrets.yml
    sed -i "s/secret_key_base:.*/secret_key_base: $secret_key_base/" config/secrets.yml
    # check if the secret key base is added
    if grep -q "secret_key_base" config/secrets.yml; then
        echo "secret_key_base added to secrets.yml"
    fi
else
    echo "config/secrets.yml already exists."
    echo "now checking if secret_key_base is added to secrets.yml"
    # check if the secret key base is added
    if grep -q "secret_key_base" config/secrets.yml; then
        echo "secret_key_base already added to secrets.yml"
    else
        echo "Adding secret key base to secrets.yml"
        # generate secret key base and store it in a variable
        secret_key_base=$(rake secret)
        # replace the secret key base in secrets.yml
        sed -i "s/secret_key_base:.*/secret_key_base: $secret_key_base/" config/secrets.yml
    fi
fi

# Now check if database.yml exists and the production database is set
if [ ! -f config/database.yml ]; then
    echo "config/database.yml not found. Now creating one."
    cp config/database.yml.example config/database.yml
    # check if the database is set to production
    if grep -q "production" config/database.yml; then
        echo "Database is set to production."
    else
        echo "Database is not set to production. Now setting it to production."
        sed -i "s/production:/production:\n  <<: \*default\n  database: openmrs_production/" config/database.yml
        echo "Database is set to production."
    fi
else
    echo "config/database.yml already exists."
fi