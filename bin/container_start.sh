#!/bin/bash

echo "3.2.0" >.ruby-version

source ~/.bashrc

# we need to check for configuration files and create them if they don't exist
if [ ! -f config/database.yml ]; then
    cp config/database.yml.example config/database.yml

    # in config/database.yml replace 3308 with 3306
    sed -i 's/3308/3306/g' config/database.yml
    sed -i 's/your_scoped_username/root/g' config/database.yml
    sed -i 's/your_secret_password/root/g' config/database.yml
else
    # use ruby to do the same thing as above
    host=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['host']")
    port=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['port']")
    adapter=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['adapter']")
    encoding=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['encoding']")
    collation=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['collation']")
    username=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['username']")
    password=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['password']")
    pool=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['pool']")
    checkout_timeout=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['checkout_timeout']")
    variables_sql_mode=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['default']['variables']['sql_mode']")
    if [ "$host" != "127.0.0.1" ]; then
        echo "Updating host configuration"
        sed -i "s/$host/127.0.0.1/g" config/database.yml
    fi
    if [ "$port" != "3306" ]; then
        echo "Updating port configuration"
        sed -i "s/$port/3306/g" config/database.yml
    fi
    if [ "$adapter" != "mysql2" ]; then
        echo "Updating adapter configuration"
        sed -i "s/$adapter/mysql2/g" config/database.yml
    fi
    if [ "$encoding" != "utf8" ]; then
        echo "Updating encoding configuration"
        sed -i "s/$encoding/utf8/g" config/database.yml
    fi
    if [ "$collation" != "utf8_unicode_ci" ]; then
        echo "Updating collation configuration"
        sed -i "s/$collation/utf8_unicode_ci/g" config/database.yml
    fi
    if [ "$username" != "root" ]; then
        echo "Updating username configuration"
        sed -i "s/$username/root/g" config/database.yml
    fi
    if [ "$password" != "root" ]; then
        echo "Updating password configuration"
        sed -i "s/$password/root/g" config/database.yml
    fi
    if [ "$pool" != "<%= ENV.fetch(\"RAILS_MAX_THREADS\") { 20 } %>" ]; then
        echo "Updating pool configuration"
        sed -i "s/$pool/<%= ENV.fetch(\"RAILS_MAX_THREADS\") { 20 } %>/g" config/database.yml
    fi
    if [ "$checkout_timeout" != "5000" ]; then
        echo "Updating checkout_timeout configuration"
        sed -i "s/$checkout_timeout/5000/g" config/database.yml
    fi
    if [ "$variables_sql_mode" != "STRICT_TRANS_TABLES" ]; then
        echo "Updating variables_sql_mode configuration"
        sed -i "s/$variables_sql_mode/STRICT_TRANS_TABLES/g" config/database.yml
    fi
fi

# we have to ensure that the database.yml file is properly configured with the values above irregardless

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

bundle install

if [ ! -f config/secrets.yml ]; then
    bash bin/setup_production_mode.sh
fi

# read the database configuration and check if the database exists
# if it doesn't exist, create it
# if it exists, run the migrations
#!/bin/bash

# Parse database.yml file
development_db=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['database']")
test_db=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['test']['database']")
production_db=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['production']['database']")

USERNAME=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['username']")
PASSWORD=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['password']")
DATABASE=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['database']")
HOST=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['host']")
PORT=$(ruby -ryaml -e "puts YAML.safe_load(File.read('config/database.yml'), aliases: true)['development']['port']")

# Array of databases
databases=($development_db $test_db $production_db)

# Check if databases exist based on environment and use the initialization scripts to create them
# 0 - development, 1 - test, 2 - production
for i in "${databases[@]}"; do
    if [ "$i" == "$development_db" ]; then
        ENV="development"
    elif [ "$i" == "$test_db" ]; then
        ENV="test"
    elif [ "$i" == "$production_db" ]; then
        ENV="production"
    fi

    # check if the database exists
    result=$(mysql --host=$HOST --user=$USERNAME --port=$PORT --password=$PASSWORD -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$i'")

    # check if the result is empty and create the database
    if [ -z "$result" ]; then
        bin/initial_database_setup.sh $ENV mpc
        bin/update_art_metadata.sh $ENV
    fi
done

current_dir=$(basename "$PWD")

if [ "$(git config --global --get safe.directory)" != "/workspaces/$current_dir" ]; then
    git config --global --add safe.directory /workspaces/$current_dir
fi
