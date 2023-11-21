# Code Documentation
## Summary
The code is a class called 'DashboardStats' that generates a report of dashboard statistics for a given date range. It retrieves the total number of encounters for each encounter type, both at the facility level and for an individual. The class uses SQL queries to fetch the data from the database and returns a hash of the dashboard statistics.

## Example Usage
```ruby
start_date = Date.new(2022, 1, 1)
end_date = Date.new(2022, 1, 31)
dashboard_stats = AetcService::Reports::Clinic::DashboardStats.new(start_date, end_date)
report = dashboard_stats.find_report
puts report
```
Expected output:
```
[
  {
    "name" => "SOCIAL HISTORY",
    "me" => 10,
    "facility" => 20,
    "total" => 30
  },
  {
    "name" => "PATIENT REGISTRATION",
    "me" => 5,
    "facility" => 15,
    "total" => 20
  },
  ...
]
```

## Code Analysis
### Inputs
- `start_date` (Date): The start date to generate the report for.
- `end_date` (Date): The end date to limit the result.
___
### Flow
1. The class `DashboardStats` is initialized with a start date and an end date.
2. The `find_report` method is called, which internally calls the `patient_providers_encounters` method.
3. The `patient_providers_encounters` method executes a SQL query to fetch the total number of encounters for each encounter type.
4. The query joins three tables: `encounter_type`, `encounter`, and `program`.
5. The result is grouped by encounter type and includes the total encounters for the facility level and for an individual provider.
6. The encounter type IDs are retrieved using the `encounter_type_ids` method.
7. The method returns a hash of the dashboard statistics.
___
### Outputs
Spits out an array of hashes with the following keys:
- `name` (String): The name of the encounter type.
- `me` (Integer): The total number of encounters for the individual provider.
- `facility` (Integer): The total number of encounters for the facility.
- `total` (Integer): The total number of encounters for the individual provider and the facility.

[Back to Home](../README.md)