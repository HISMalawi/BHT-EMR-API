# HIS-EMR-API - Quick Start Guide

Get the HIS-EMR-API running in 11 simple steps.

---

## Prerequisites

Before starting, ensure you have:
- ✅ Ruby 3.2+ installed
- ✅ Rails 7.0+ installed
- ✅ MySQL 5.6+ installed and running
- ✅ Git installed
- ✅ Nodejs version 14+ 
- 

---

## Step 1: Clone the Repository

```bash
cd ~/Projects/mahis
git clone https://github.com/HISMalawi/BHT-EMR-API HIS-EMR-API
cd HIS-EMR-API
```

## Step 2: Install Ruby Gems

Install all required Ruby dependencies:

```bash
bundle install
```
---

## Step 3: Configure Database Connection

Create the database configuration file:

```bash
cp config/database.yml.example config/database.yml
```

Edit the file with your MySQL credentials:

```bash
nano config/database.yml
```

Update the following values:
```yaml
default: &default
  host: localhost          # Your MySQL server
  port: 3306                # Your MySQL port
  username: root            # Your MySQL username
  password: your_password   # Your MySQL password

development:
  <<: *default
  database: openmrs_dev     # Development database name

production:
  <<: *default
  database: openmrs_prod    # Production database name
```
---

## Step 4a: Create the database if not available
```bash
rails db:create
```

## Step 4b: Import the database if not available and you have a dump
```bash
  % mahis.sql | mysql -u <username> -p <database_name>
```

## Step 4c: Add metadata
 ```bash
    cat db/sql/openmrs_metadata_1_7.sql | mysql -u <username> -p <database_name>
```

Initialize global properties:
```bash
bundle exec rake db:initialize_global_properties
```

## Step 5: Configure Application Settings

Create the application configuration file:

```bash
cp config/application.yml.example config/application.yml
```

Edit the configuration:

```bash
nano config/application.yml
```

Update these key settings:
```yaml
development:
  facility_code: KCH        # Update the facility code of your configured facility

production:
  facility_code: KCH        # Update the facility code of your configured facility

lims_host: localhost
lims_port: 3010
lims_protocol: http
```

---

## Step 6: Create Databases

Create the necessary MySQL databases:

```bash
mysql -u root -p -e "CREATE DATABASE openmrs_dev;"
mysql -u root -p -e "CREATE DATABASE openmrs_prod;"
mysql -u root -p -e "CREATE DATABASE openmrs_test;"
```

---

## Step 7: Setup Database Schema and Data

Load the OpenMRS metadata and setup the database:

```bash
bin/initial_database_setup.sh development mpc
```

**For production environment:**
```bash
bin/initial_database_setup.sh production mpc
```

**For test environment:**
```bash
bin/initial_database_setup.sh test mpc
```

This script will:
- Load OpenMRS metadata
- Run migrations
- Load regimen tables
- Create initial admin user

---

## Step 8: Verify Database Setup

Run the test suite to verify everything is working:

```bash
bin/rspec
```

All tests should pass. If they do, your database setup is correct.

---

## Step 9: Start the API Server

Run the API in development mode:

```bash
bin/rails server
```

You should see output similar to:
```
=> Rails 7.0.0 application starting in development
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Listening on tcp://127.0.0.1:3000
Use Ctrl-C to stop
```

The API is now running at: **http://localhost:3000**

---

## Step 10: Configure MAHIS Frontend

In a new terminal, configure the MAHIS frontend:

```bash
cd ~/Projects/mahis/MAHIS
```

Update the API configuration to point to:
```
http://localhost:3000/api/v1
```

Install dependencies and start:

```bash
npm install
npm run dev
```
---


## Step 11: Enable and Configure Sync

The MAHIS application uses **PouchDB** (a client-side JavaScript database) for offline storage and synchronization. PouchDB runs directly in the browser and stores data in **IndexedDB** (browser's local database).

### 11a: Configure Network Settings in MAHIS

Once the API is running, open the MAHIS application in your browser and navigate to Settings:

1. Open MAHIS frontend (usually at `http://localhost:5173`)
2. Navigate to **Settings** → **Network Configuration**
3. Enable sync features:
   - ✅ Enable "Use Local Storage" (enables PouchDB/IndexedDB for offline data)
4. Save configuration

Alternatively, configure via API:

```bash
# Get authentication token
TOKEN=$(curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admini",
    "password": "test"
  }' | jq -r '.authorization.token')

# Configure network settings
curl -X POST http://lo",
    "password": "test"
  }' | jq -r '.authorization.token')

# Configure network settings
curl -X POST http://localhost:3000/api/v1/global_properties \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "property": "facility_network_config",
    "value": {
      "locationId": 1,
      "useLanConnection": false,
      "useLocalStorage": true
    }
  }'
```

### 11bk **"Sync All Data"** button
3. Watch the progress indicator as data syncs to IndexedDB (local browser storage via PouchDB)
4. Verify in browser DevTools → Application → IndexedDB that local databases are created:
   - `dde`
   - `patients_records`
   - `visits`
   - `stages`
   - `programs`
   - `facilities`
   - `drugs`
   - etc.

### 11d: Verify Sync Status

Check the sync logs in browser console:
c
```bash
# In browser console (F12)
console.log(localStorage.getItem('useLanConnection'))  // Should be "true"
console.log(localStorage.getItem('useLocalStorage'))   // Should be "true"
```

Monitor Web Worker activity in Network tab during sync.

---

## Step 12: Configure HIS-Core Frontend

In another terminal, configure the HIS-Core frontend:

```bash
cd ~/Projects/PoCsystem/HIS-Core
```

Update the API configuration to point to:
```
http://localhost:3000/api/v1
```

Install dependencies and start:

```bash
npm install
Run `ionic serve`
```

---

## Verify Everything is Working

### Test Authentication

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "test"
  }'
```

You should receive a token in the response:
```json
{
  "authorization": {
    "token": "AiJViSpF3spb",
    "expiry_time": "2024-08-28T11:01:55.501+02:00"
  }
}
```

### Access Frontends

- **MAHIS**: Usually at `http://localhost:5173` or `http://localhost:8080`
- **HIS-Core**: Usually at `http://localhost:8080` or port shown in your terminal

Login with default credentials:
- Username: `admin`
- Password: `test`

---

## Running on Different Port

If port 3000 is already in use:

```bash
bin/rails server -p 3001
```

Update frontend API URLs to: `http://localhost:3001/api/v1`

---

## Accessing from Other Devices/Machines

To allow external access (other computers, phones, tablets):

```bash
bin/rails server -b 0.0.0.0 -p 3000
```

Then use your server's IP address:
```
http://<server-ip>:3000/api/v1
```

---

## Running as a System Service (Production)

For production environments, create a system service:

```bash
sudo chmod +x ./bin/create_service.sh
sudo ./bin/create_service.sh
```

Then manage with:

```bash
sudo service emr-api start
sudo service emr-api stop
sudo service emr-api restart
sudo service emr-api status
```

---

## Troubleshooting Quick Fixes

### "API Version Mismatch"
Ensure you're on the correct version of the API. Follow these steps to check, pull updates, and checkout to the required tag:

#### Step 1: Check Current Branch/Tag
```bash
# Show which branch or tag you're currently on
git status

#### Step 2: List Available Tags
```bash
# Show all available tags (remotely)
git tag -l

# Show only 10 recent tags
git tag -l | sort -V | tail -10
```

#### Step 2: Checkout to Specific Tag

**Option: Checkout to a specific tag (detached HEAD state)**
```bash
# Checkout to a specific tag (e.g., v5.9.9)
git checkout v5.9.9

# Or the latest tag
git checkout $(git describe --tags --abbrev=0)
```

### "Cannot connect to database"
Check MySQL is running:
```bash
sudo service mysql status
```

### "Port 3000 already in use"
Use a different port:
```bash
bin/rails server -p 3001
```

### "Gem dependencies missing"
Reinstall gems:
```bash
bundle install
```

### "Database errors"
Reset and setup database:
```bash
bin/initial_database_setup.sh development mpc
```
---

## Next Steps

For detailed information about:
- DDE integration
- Production deployment
- Advanced configuration
- Development guidelines

See the main **[README.md](README.md)** file.

---

**Need Help?** Check the troubleshooting section in README.md or review the API logs:
```bash
tail -f log/development.log
```
