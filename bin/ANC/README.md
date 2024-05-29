This section contains a set of scripts to be used to clean ANC data

#### FIX PATIENTS WITH MULTIPLE LMP

- This data cleaning script will void any duplicate CURRENT PREGNANCY encounter that was recorded in the same pregnancy after the first visit

##### Running the script

- on the root dir of the project, run the following script

```bash
rails r bin/fix_patients_with_dup_lmp.rb
```