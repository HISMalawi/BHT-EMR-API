#!bin/bash
env=$1

function usage(){

    echo "Usage: $0 ENVIRONMENT"
    echo
    echo "ENVIRONMENT should be: development|test|production"

}

if [ -z "$env" ]; then
    usage
    exit 1
fi

# remove gemlock and reinstall from local cache
rm Gemfile.lock
bundle install --local

if [ $? -eq 0 ]; then
    echo "bundle installed successfully"
else
    echo "bundle installation failed"
    exit 1
fi

# cp local_queue configs
cp ./config/recurring.yml.example ./config/recurring.yml
cp ./config/queue.yml.example ./config/queue.yml

# migrate local_queue_tables
rails solid_queue:install

if [ $? -eq 0 ]; then
    echo "solid_queue installed successfully"
else
    echo "solid_queue installation failed"
    exit 1
fi

#run DB schema
rails db:schema:dump

# check if tables already exists in database
if cat ./db/schema.rb | grep -q "solid_queue"; then
    echo "solid_queue tables already exists in database"
else
    echo "solid_queue tables not found in database migrating ..."

    rails r ./db/queue_schema.rb    
fi

# migrate solid queue tables

if [ $? -eq 0 ]; then
    echo "solid_queue tables migrated successfully"
    # remove the schema file
    rm ./db/queue_schema.rb
else
    echo "solid_queue tables migration failed"
    exit 1
fi


# revert whatever changes solidqueue:setup script has done to this file
git checkout ./config/environments/production.rb

# run update_art_metadata_sh
bash ./bin/update_art_metadata.sh $env

# cdr:
#   url: http://localhost:3001/api/v1/stream
#   username: admin
#   password: password
# add cdr config in application.yml file like above
output_file="./config/application.yml"

if [ -f "$output_file" ]; then
    sed -i "s/cdr:\s*url:.*/cdr:\n  url: http:\/\/localhost:3001\/api\/v1\/stream/g" $output_file
    sed -i "s/cdr:\s*username:.*/cdr:\n  username: admin/g" $output_file
    sed -i "s/cdr:\s*password:.*/cdr:\n  password: password/g" $output_file
fi

# print a fancy complete line
#!/bin/bash

# Define colors
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"
BOLD="\033[1m"

# Print a fancy line with a decorative message
echo -e "${BLUE}=========================================${RESET}"
echo -e "${GREEN}${BOLD}           Setup Complete!              ${RESET}"
echo -e "${BLUE}=========================================${RESET}"

echo -e "${GREEN}${BOLD} Your Application is now setup for streaming ${RESET}"

# print instructions
echo ""
echo "but BEFORE YOU START your application "
echo "Please enter correct CDR details in application.yml file"
echo "and make sure database.yml file has queue configurations, see database.yml.example for details"

