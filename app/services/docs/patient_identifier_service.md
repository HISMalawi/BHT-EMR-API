# Code Documentation
## Summary
The code snippet is a part of the `PatientIdentifierService` module in Ruby. It contains several methods related to managing patient identifiers, such as finding duplicates, finding multiples, creating new identifiers, and swapping active numbers between patients.

## Example Usage
```ruby
# Find duplicates of a specific identifier type
duplicates = PatientIdentifierService.find_duplicates(identifier_type)

# Find multiples of a specific identifier type
multiples = PatientIdentifierService.find_multiples(identifier_type)

# Create a new patient identifier
params = { patient_id: 1, identifier_type: identifier_type, identifier: 'ABC123' }
PatientIdentifierService.create(params)

# Swap active numbers between two patients
params = { primary_patient_id: 1, secondary_patient_id: 2, identifier: 'ABC123' }
PatientIdentifierService.swap_active_number(params)
```

## Code Analysis
### Inputs
- `identifier_type`: An object representing the type of identifier to be searched, created, or swapped.
___
### Flow
1. The `find_duplicates` method queries the database to find duplicate identifiers of a specific type.
2. The `find_multiples` method fetches data about patients who have multiple identifiers of a specific type.
3. The `create` method validates the new identifier, voids any existing identifier for the same patient and type, and creates a new identifier.
4. The `swap_active_number` method validates the identifier assignment, voids filing numbers for both patients, and switches the active and archive numbers.
___
### Outputs
- The `find_duplicates` method returns an array of hashes, each containing the count and identifier of a duplicate.
- The `find_multiples` method returns an array of patient data, including their identifiers.
- The `create` method returns the newly created identifier object.
- The `swap_active_number` method returns a hash with details about the swapped numbers and patients.
___

[Back to Menu](../README.md)