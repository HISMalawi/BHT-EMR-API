# Metadata Merge Script

This script merges two OpenMRS databases by combining their metadata and transactional tables. Here's how it works:

1. Creates a new database
2. Loads the master metadata into the new database
3. For each metadata table:
   - Selects data from slave table that doesn't exist in master (using UUID)
   - Inserts the data into the master table
   - Creates a temp_mapping table to track mappings between slave and master tables
   - Dumps the master metadata into the slave database
4. For each transactional table:
   - Updates the transactional table to use the new UUIDs from the temp_mapping table

## Usage

### Pre-requisites

1. Add the following to your `database.yml`:
   - A `metadata_server_local` database configuration that points to the local metadata database that will be created
     - This database will be created by the script.
    ```yaml
    metadata_server_local:
      <<: *default  
      database: openmrs_metadata
    ```

   - A `metadata_server` database configuration that points to the remote metadata database that has the latest metadata
    ```yaml
    metatata_server:
      <<: *default
      database: openmrs_metadata
    ```

### Usage

- Run the script:
    ```bash
    rails runner bin/metadata/remap.rb
    ```

