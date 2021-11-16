puma=$(which puma)
rail_modes=("test" "development" "production")

actions() {
    read -p "Enter BHT-EMR-API full path: " app_dir
}

actions
while [ ! -d $app_dir ]; do
    echo "Directory $app_dir DOES NOT EXISTS."
    actions
done

app_core=$(grep -c processor /proc/cpuinfo)


read -p "Enter PORT: " app_port
read -p "Enter maximum number of threads to run: " app_threads

PS3="Please select a RAILS ENVIRONMENT: "
select mode in ${rail_modes[@]}
do
    if [ -z "$mode" ]; then
        echo "invalid option selected"
    else
        echo "$mode selected"
        break
    fi
done

env=$mode

if systemctl --all --type service | grep -q "puma.service";then
    echo "stopping service"
    sudo systemctl stop puma.service
    sudo systemctl disable puma.service
    echo "service stopped"
else
    echo "Setting up service"
fi

echo "Writing the service"
echo "[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple

User=$USER

WorkingDirectory=$app_dir

Environment=RAILS_ENV=$env

ExecStart=/bin/bash -lc 'rvm use 2.5.3 && ${puma} -C ${app_dir}/config/server/development.rb'

Restart=always

KillMode=process

[Install]
WantedBy=multi-user.target" > puma.service

sudo cp ./puma.service /etc/systemd/system

echo "Writing puma configuration"

[ ! -d ${app_dir}/config/server ] && mkdir ${app_dir}/config/server

echo "# Puma can serve each request in a thread from an internal thread pool.
# The threads method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
threads_count = ENV.fetch('RAILS_MAX_THREADS') { $app_threads }
threads 5, threads_count

# Specifies the port that Puma will listen on to receive requests; default is 3000.
#
port        ENV.fetch('PORT') { $app_port }

# Specifies the environment that Puma will run in.
#
environment ENV.fetch('RAILS_ENV') { '$env' }

# Specifies the number of workers to boot in clustered mode.
workers ENV.fetch('WEB_CONCURRENCY') { $app_core }

# Use the preload_app! method when specifying a workers number.

preload_app!

# Allow puma to be restarted by rails restart command.
plugin :tmp_restart

rackup '${app_dir}/config.ru'" > development.rb

sudo cp ./development.rb ${app_dir}/config/server/


echo "Firing the service up"

sudo systemctl daemon-reload
sudo systemctl enable puma.service
sudo systemctl start puma.service

echo "Service fired up"
echo "Cleaning up"
rm ./puma.service
rm ./development.rb
echo "Cleaning up done"

echo "complete"