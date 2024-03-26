echo "You are about to create a service for the EMR-API please follow the instructions carefully"

rails=""

if command -v rvm > /dev/null 2>&1; then
    rvm use 3.2.0
    rails=$(which rails)
elif command -v rbenv > /dev/null 2>&1; then
    rbenv shell 3.2.0
    rails=$(which rails)
else
    echo "Neither RVM nor rbenv is installed. You will need to install the service manually."
    # Handle the error case here. For example, you might want to exit with an error code.
    exit 1
fi

rail_modes=("test" "development" "production")

actions() {
    read -p "Enter EMR-API full path: " app_dir
}

actions
while [ ! -d $app_dir ]; do
    echo "Directory $app_dir DOES NOT EXISTS."
    actions
done

app_core=$(grep -c processor /proc/cpuinfo)


read -p "Enter PORT: " app_port

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

if systemctl --all --type service | grep -q "emr-api.service";then
    echo "stopping emr-api service"
    sudo systemctl stop emr-api.service
    sudo systemctl disable emr-api.service
    echo "service stopped"
elif systemctl --all --type service | grep -q "puma.service";then
    echo "stoppping puma service"
    sudo systemctl stop puma.service
    sudo systemctl disable puma.service
    echo "service stopped"
else
    echo "Setting up service"
fi

echo "Writing the service"
echo "[Unit]
Description=EMR-API Puma Server
After=network.target

[Service]
Type=simple

User=$USER

WorkingDirectory=$app_dir

ExecStart=/bin/bash -lc \"${rails} s -b 0.0.0.0 -p $app_port -e $env\"

Restart=always

KillMode=process

[Install]
WantedBy=multi-user.target" > emr-api.service

sudo cp ./emr-api.service /etc/systemd/system

echo "Firing the service up"

sudo systemctl daemon-reload
sudo systemctl enable emr-api.service
sudo systemctl start emr-api.service

echo "Service fired up"
echo "Cleaning up"
rm ./emr-api.service
echo "Cleaning up done"

echo "complete"