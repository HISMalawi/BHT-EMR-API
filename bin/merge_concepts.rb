LOGGER = Logger.new($stdout)
User.current = User.first
new_concepts_file = File.new('merge_concepts.csv', 'w+')
new_concepts_file.puts('concept_id, concept_name, status')

default_db_config = Rails.configuration.database_configuration['development']
concepts_db_config = Rails.configuration.database_configuration['concepts_merge_db']

# Concepts in concepts database that are not present in database development
records_to_insert = ConceptName.connection.select_all(format("
  SELECT cn.name, c.creator, c.class_id, c.datatype_id
  FROM %<database_b>s.concept_name cn
  INNER JOIN %<database_b>s.concept c ON c.concept_id = cn.concept_id
  WHERE name NOT IN (SELECT name FROM %<database_a>s.concept_name)
", database_a: default_db_config['database'], database_b: concepts_db_config['database'])).to_hash

LOGGER.info("Found #{records_to_insert.count} records that needs to be merged")

# Insert the missing records into the development DB
records_inserted = 0
ActiveRecord::Base.transaction do
  records_to_insert.each do |record|
    LOGGER.info("creating new concept #{record['name']}")
    concept = Concept.create(
      short_name: record['name'],
      creator: record['creator'],
      class_id: record['class_id'],
      datatype_id: record['datatype_id'],
    )
    ConceptName.create(
      concept_id: concept.id,
      name: concept.short_name,
    )
    records_inserted += 1
    new_concepts_file.puts("#{concept.id}, #{record['name']}, created")
  rescue e
    LOGGER.error("Failed to create concept #{record['name']}")
    new_concepts_file.puts("#{concept.id}, #{record['name']}, failed, #{e.message}")
  end
  new_concepts_file.close
end

LOGGER.info("Inserted #{records_inserted} records")
