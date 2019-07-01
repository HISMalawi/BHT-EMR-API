# frozen_string_literal: true

require 'ostruct'

@RDS_DUMP_RUNNING = true
require_relative 'rds_push'

@rds_configuration[:mode] = MODE_DUMP

def main
  File.open(Rails.root.join('log', 'rds_dump.sql'), 'w') do |fout|
    config['databases'].each do |database, database_config|
      dump(database, database_config['program_name'], fout)
    end
  end
end

# Dump database in an RDS compatible format into given file.
def dump(database, program_name, file)
  file.write("SET foreign_key_checks = 0;\n")

  program = Program.find_by_name(program_name)

  MODELS.each do |model|
    records = recent_records(model, TIME_EPOCH, database)

    last_record_container = OpenStruct.new

    # Chunk retrieved records while converting them to JSON at the same time.
    record_chunks = chunk_records(records, RECORDS_BATCH_SIZE) do |record|
      last_record_container.record = record

      record = serialize_record(record, program)
      record.delete('record_type')
      record
    end

    # Convert the chunks to SQL INSERT statements and write them to file
    record_chunks.each do |chunk|
      record_fields = chunk.first.keys

      sql_values = chunk.map do |record|
        values = record_fields.map { |field| sql_quote(record[field]) }

        "(#{values.join(', ')})"
      end

      sql_statement = <<~SQL
        INSERT IGNORE INTO #{model.table_name} (#{record_fields.join(', ')})
        VALUES #{sql_values.join(', ')};
      SQL

      file.write(sql_statement)
    end

    next unless last_record_container.record

    save_database_offset(model, record_update_time(last_record_container.record), database)
  end

  file.write("SET foreign_key_checks = 1;\n")
end

# Converts an enumerator (generator) of records into an enumerator
# of arrays of records of the given batch_size.
def chunk_records(records, batch_size)
  Enumerator.new do |enum|
    chunked_records = []

    records.each do |record|
      if chunked_records.size == batch_size
        enum.yield(chunked_records)
        chunked_records = []
      end

      transformed_record = block_given? ? yield(record) : record
      chunked_records.push(transformed_record)
    end

    # Yield the remaining records if any
    enum.yield(chunked_records) unless chunked_records.empty?
  end
end

def sql_quote(text)
  ActiveRecord::Base.connection.quote(text)
end

main
