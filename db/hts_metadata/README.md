## CommCare Configuration Script Setup Guide

This guide provides step-by-step instructions on how to set up and run the CommCare Configuration Script, which simplifies the configuration process for a CommCare sync configuration with the EMR.

## Running the Script
 - Open a terminal/command prompt.
 - Navigate to the app directory.
 - Run the script:
  
```shell
rails r bin/config_commcare.rb
```

### Environment Selection
- Choose environment: Enter '1' for Development or '2' for Production.
- Loading Excel Data

- The script loads data from specified environment.
  
### Site Code Entry
 - Enter site code to identify the health facility.
  
### Verification
- Review facility information displayed.
- Confirm the correctness.
  
### Username and Password
- Enter CommCare username and password.
  
### Configuration Setup
- The script compiles collected info into a configuration object.
- Updates a YAML file 'config/ait.yml'.
  
### Completion
- Script provides feedback on configuration save.