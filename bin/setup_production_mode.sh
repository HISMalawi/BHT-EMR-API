#!/bin/bash

function create_secret(){
    echo "Adding secret key base to secrets.yml"
    # generate secret key base and store it in a variable
    secret_key_base=$(rake secret)
    # replace the secret key base in secrets.yml
    sed -i "s/secret_key_base:.*/secret_key_base: $secret_key_base/" config/secrets.yml
    echo "Done"
}

# check if config folder has secret.yml
if [ ! -f config/secrets.yml ]; then
    echo "config/secrets.yml not found. Now creating one."
    cp config/secrets.yml.example config/secrets.yml
else
    echo "config/secrets.yml already exists."
fi
echo "now checking if secret_key_base is added to secrets.yml"
if grep -q "secret_key_base:" config/secrets.yml; then
    echo "secret_key_base is present in secrets.yml, now checking if it has a value"
    # check if secret_key_base has a value
    if grep -q "secret_key_base: ^[0-9a-fA-F]{128}$" config/secrets.yml; then
        echo "secret_key_base is present and has a value in secrets.yml, skipping..."
    else
        echo "secret_key_base is present but has no value in secrets.yml"
        create_secret
    fi
else
    echo "secret_key_base is not present in secrets.yml"
    # add a secret key base to secrets.yml under production
    sed -i "/^production:/a \ \ secret_key_base:" config/secrets.yml
    create_secret
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

echo "Now you can run your api in production mode: RAILS_ENV=production rails s"