# frozen_string_literal: true

require 'csv'
require 'parallel'

require 'couch_bum/couch_bum'
require 'logger_multiplexor'

require 'concept'
require 'concept_name'
require 'drug_order'
require 'encounter'
require 'encounter_type'
require 'observation'
require 'order'
require 'order_type'
require 'patient'
require 'patient_identifier'
require 'patient_identifier_type'
require 'person'
require 'person_name'
require 'program'
require 'user'

require 'lab/lab_encounter'
require 'lab/lab_order'
require 'lab/lab_result'
require 'lab/lab_test'
require 'lab/lims_order_mapping'
require 'lab/lims_failed_import'

require_relative './api/couchdb_api'
require_relative './config'
require_relative './pull_worker'
require_relative './utils'

require_relative '../orders_service'
require_relative '../results_service'
require_relative '../tests_service'
require_relative '../../../serializers/lab/lab_order_serializer'
require_relative '../../../serializers/lab/result_serializer'
require_relative '../../../serializers/lab/test_serializer'

require_relative 'order_dto'
require_relative 'utils'

module Lab
  module Lims
    ##
    # Tools for performing a bulk import of data from LIMS' databases to local OpenMRS database.
    #
    # Migration sources supported:
    #   - MySQL
    #   - CouchDB
    #
    # The sources above can be changed by setting the environment various MIGRATION_SOURCE to
    # either mysql or couchdb.
    module Migrator
      MAX_THREADS = ENV.fetch('MIGRATION_WORKERS', 6).to_i

      ##
      # A Lab::Lims::Api object that supports crawling of a LIMS CouchDB instance.
      class CouchDbMigratorApi < Lab::Lims::Api::CouchDbApi
        def initialize(*args, processes: 1, on_merge_processes: nil, **kwargs)
          super(*args, **kwargs)

          @processes = processes
          @on_merge_processes = on_merge_processes
        end

        def consume_orders(from: nil, **_kwargs)
          limit = 25_000

          loop do
            on_merge_processes = ->(_item, index, _result) { @on_merge_processes&.call(from + index) }
            processes = @processes > 1 ? @processes : 0

            orders = read_orders(from, limit)
            break if orders.empty?

            Parallel.each(orders, in_processes: processes, finish: on_merge_processes) do |row|
              next unless row['doc']['type']&.casecmp?('Order')

              User.current = Utils.lab_user
              yield OrderDTO.new(row['doc']), OpenStruct.new(last_seq: (from || 0) + limit, current_seq: from)
            end

            from += orders.size
          end
        end

        private

        def read_orders(from, batch_size)
          start_key_param = from ? "&skip=#{from}" : ''
          url = "_all_docs?include_docs=true&limit=#{batch_size}#{start_key_param}"

          Rails.logger.debug("#{CouchDbMigratorApi}: Pulling orders from LIMS CouchDB: #{url}")
          response = bum.couch_rest :get, url

          response['rows']
        end
      end

      ##
      # Extends the PullWorker to provide pause/resume capabilities.
      #
      # Migrations can be take a long time to complete, in cases where something
      # went wrong you wouldn't to start all over. This worker thus saves
      # progress and allows for the process to continue from whether it stopped.
      class MigrationWorker < PullWorker
        LOG_FILE_PATH = Utils::LIMS_LOG_PATH.join('migration-last-id.dat')

        attr_reader :rejections

        def initialize(api_class)
          api = api_class.new(processes: MAX_THREADS, on_merge_processes: method(:save_seq))
          super(api)
        end

        def last_seq
          return 0 unless File.exist?(LOG_FILE_PATH)

          File.open(LOG_FILE_PATH, File::RDONLY) do |file|
            last_seq = file.read&.strip
            return last_seq.blank? ? nil : last_seq&.to_i
          end
        end

        private

        def save_seq(last_seq)
          File.open(LOG_FILE_PATH, File::WRONLY | File::CREAT, 0o644) do |file|
            Rails.logger.debug("Process ##{Parallel.worker_number}: Saving last seq: #{last_seq}")
            file.flock(File::LOCK_EX)
            file.write(last_seq.to_s)
            file.flush
          end
        end

        def order_rejected(order_dto, reason)
          @rejections ||= []

          @rejections << OpenStruct.new(order: order_dto, reason: reason)
        end
      end

      def self.save_csv(filename, rows:, headers: nil)
        CSV.open(filename, File::WRONLY | File::CREAT) do |csv|
          csv << headers if headers
          rows.each { |row| csv << row }
        end
      end

      # NOTE: LIMS_LOG_PATH below is defined in worker.rb
      MIGRATION_REJECTIONS_CSV_PATH = Utils::LIMS_LOG_PATH.join('migration-rejections.csv')

      def self.export_rejections(rejections)
        headers = ['doc_id', 'Accession number', 'NHID', 'First name', 'Last name', 'Reason']
        rows = (rejections || []).map do |rejection|
          [
            rejection.order[:_id],
            rejection.order[:tracking_number],
            rejection.order[:patient][:id],
            rejection.order[:patient][:first_name],
            rejection.order[:patient][:last_name],
            rejection.reason
          ]
        end

        save_csv(MIGRATION_REJECTIONS_CSV_PATH, headers: headers, rows: rows)
      end

      MIGRATION_FAILURES_CSV_PATH = Utils::LIMS_LOG_PATH.join('migration-failures.csv')

      def self.export_failures
        headers = ['doc_id', 'Accession number', 'NHID', 'Reason', 'Difference']
        rows = Lab::LimsFailedImport.all.map do |failure|
          [
            failure.lims_id,
            failure.tracking_number,
            failure.patient_nhid,
            failure.reason,
            failure.diff
          ]
        end

        save_csv(MIGRATION_FAILURES_CSV_PATH, headers: headers, rows: rows)
      end

      MIGRATION_LOG_PATH = Utils::LIMS_LOG_PATH.join('migration.log')

      def self.start_migration
        Dir.mkdir(Utils::LIMS_LOG_PATH) unless File.exist?(Utils::LIMS_LOG_PATH)

        logger = LoggerMultiplexor.new(Logger.new($stdout), MIGRATION_LOG_PATH)
        logger.level = :debug
        Rails.logger = logger
        ActiveRecord::Base.logger = logger
        # CouchBum.logger = logger

        api_class = case ENV.fetch('MIGRATION_SOURCE', 'couchdb').downcase
                    when 'couchdb' then CouchDbMigratorApi
                    when 'mysql' then Api::MysqlApi
                    else raise "Invalid MIGRATION_SOURCE: #{ENV['MIGRATION_SOURCE']}"
                    end

        worker = MigrationWorker.new(api_class)
        worker.pull_orders(batch_size: 10_000)
      ensure
        worker && export_rejections(worker.rejections)
        export_failures
      end
    end
  end
end
