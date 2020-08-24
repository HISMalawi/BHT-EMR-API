# frozen_string_literal: true

require 'ostruct'

class << self
  include RdsService

  def rds_configuration
    @rds_configuration ||= { mode: RdsService::MODE_DUMP }
  end
end

def load_flags
  ARGV.each_with_object({}) do |arg, flags|
    case arg
    when '--all'
      flags[:dump_all] = true
    else
      raise "Invalid command line argument: #{arg}"
    end
  end
end

def dump_file_name
  #name rds dump with current_health_center_name
  facility_name = GlobalProperty.find_by_property('current_health_center_name')['property_value']
  return facility_name.parameterize.underscore
end

def main
  flags = load_flags
  if flags.blank?
    rds_dump_file_name = 'rds_' + dump_file_name + '_dump_' + Date.today.strftime('%d_%m_%Y') + '.sql'
  else
    rds_dump_file_name = 'rds_' + dump_file_name + '_dump.sql'
  end


  File.open(Rails.root.join('log', rds_dump_file_name), 'w') do |fout|
    config['databases'].each do |database, database_config|
      dump(database, database_config['program_name'], fout, **flags)
    end
  end
  puts 'compressing dump file'
  `gzip #{Rails.root.join('log',rds_dump_file_name)}`
end

# Dump database in an RDS compatible format into given file.
def dump(database, program_name, file, dump_all: false)
  file.write("SET foreign_key_checks = 0;\n")

  program = Program.find_by_name(program_name)

  RdsService::MODELS.each do |model|
    offset = dump_all ? RdsService::TIME_EPOCH : database_offset(model, database)
    records = recent_records(model, offset, database)

    last_record_container = OpenStruct.new

    # Chunk retrieved records while converting them to JSON at the same time.
    record_chunks = chunk_records(records, RdsService::RECORDS_BATCH_SIZE) do |record|
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
        REPLACE INTO #{model.table_name} (#{record_fields.join(', ')})
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
