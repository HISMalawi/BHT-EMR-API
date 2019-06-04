Instructions to merge ANC data into the ART database.
-------------------------------------------------------------------------------------------------------------
1. cd in BHT-EMP-API
2. Open for edit config/database.yml and add the following section
anc_database:
  adapter: mysql2
  username: dbs_username
  database: dbs_name
  password: dbs_password
  host: localhost
  pool: 500
  
   Note: In this section please enter the details of the ANC database 
3. Make sure the ART database is named appropriately
4. Run the following script:
	./bin/anc_data_merge_script.sh development
5. Check in your home folder for a .csv file which contains ANC patient details that were not migrated. The name is: ANC_remaining_patients.csv

Note: The assumption is that the ART database is the one ART (based on the new architecture is running) and that the script of initializing the program_id was already done. If not so please do this
    ./bin/existing_database_setup.sh development 


patient_identifier
