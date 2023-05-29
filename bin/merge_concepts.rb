LOGGER = Logger.new($stdout)
User.current = User.first

default_db_config = Rails.configuration.database_configuration['development']
concepts_db_config = Rails.configuration.database_configuration['concepts_merge_db']

# Concepts in concepts database that are not present in database development
records_to_insert = ConceptName.connection.select_all(format("
  SELECT *
  FROM %<database_b>s.concept_name cn
  WHERE name NOT IN (SELECT name FROM %<database_a>s.concept_name)
", database_a: default_db_config['database'], database_b: concepts_db_config['database'])).to_hash

LOGGER.info("Found #{records_to_insert.count} records that needs to be merged")

# Insert the missing records into the development DB
records_inserted = 0
begin
  records_to_insert.each do |record|
    LOGGER.info("creating new concept #{record['name']}")
    concept = Concept.create(
      short_name: record['name'],
      creator: record['creator'],
      class_id: 3,
      datatype_id: 4
    )
    ConceptName.create(
      concept_id: concept.id,
      name: concept.short_name
    )
    records_inserted += 1
  end
rescue StandardError => e
  LOGGER.error("Error inserting record with name #{e.message}")
end

LOGGER.info("Inserted #{records_inserted} records")
