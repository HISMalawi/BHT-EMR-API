# Initialize an empty array to store the result
result_array = []

# Iterate over specimen types
Lab::ConceptsService.specimen_types().each do |type|
    # Initialize an empty array to store test types for the current specimen type
    test_types_array = []

    # For each specimen type, iterate over test types
    Lab::ConceptsService.test_types(name: nil, specimen_type: type.name).each do |spec|
        # Query test result indicators associated with the test type
        indicators = Lab::ConceptsService.test_result_indicators(spec.concept_id)
        
        # Construct a hash representing a test type with its indicators
        test_type_hash = {
            testType: spec.name,
            indicators: indicators
        }
        
        # Add the test type hash to the test types array
        test_types_array << test_type_hash
    end
    
    # Construct a hash representing the current specimen type with its test types
    specimen_hash = {
        specimen: type.name,
        testTypes: test_types_array
    }
    
    # Add the specimen hash to the result array
    result_array << specimen_hash
end

# Print or return the result array
puts result_array.to_json

require 'json'

# Your code to construct the result_array...

# Specify the file path where you want to save the JSON data
file_path = "result.json"

# Open the file in write mode and write the JSON data
File.open(file_path, "w") do |file|
  file.write(JSON.pretty_generate(result_array))
end

puts "JSON data has been saved to #{file_path}"
