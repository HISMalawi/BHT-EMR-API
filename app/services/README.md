# Service Layer Documentation
## Summary
The service layer is a collection of modules that contain methods for performing common tasks. These methods are used by controllers and other modules to perform tasks such as creating and updating records, searching for data, and generating reports.

## Example Usage
```ruby
# Find duplicates of a specific identifier type
duplicates = PatientIdentifierService.find_duplicates(identifier_type)
```

## List of Services
- [Patient Identifier Service](docs/patient_identifier_service.md)
- [Filing Number Service](docs/filing_number_service.md)