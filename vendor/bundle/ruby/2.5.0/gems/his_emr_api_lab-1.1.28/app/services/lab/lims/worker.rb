# frozen_string_literal: true

require 'logger_multiplexor'

require_relative './api/couchdb_api'

module Lab
  module Lims
    ##
    # Pull/Push orders from/to the LIMS queue (Oops meant CouchDB).
    module Worker
      def self.start
        User.current = Utils.lab_user

        fork(&method(:start_push_worker))
        fork(&method(:start_pull_worker))
        fork(&method(:start_acknowledgement_worker))
        fork(&method(:start_realtime_pull_worker)) if realtime_updates_enabled?

        Process.waitall
      end

      def self.start_push_worker
        start_worker('push_worker') do
          worker = PushWorker.new(lims_api)

          worker.push_orders # (wait: true)
        end
      end

      def self.start_acknowledgement_worker
        start_worker('acknowledgement_worker') do
          worker = AcknowledgementWorker.new(lims_api)
          worker.push_acknowledgement
        end
      end

      def self.start_pull_worker
        start_worker('pull_worker') do
          worker = PullWorker.new(lims_api)

          worker.pull_orders
        end
      end

      def self.start_realtime_pull_worker
        start_worker('realtime_pull_worker') do
          worker = PullWorker.new(Lims::Api::WsApi.new(Lab::Lims::Config.updates_socket))

          worker.pull_orders
        end
      end

      LOG_FILES_TO_KEEP = 5
      LOG_FILE_SIZE = 500.megabytes

      def self.start_worker(worker_name)
        Rails.logger = LoggerMultiplexor.new(file_logger(worker_name), $stdout)
        ActiveRecord::Base.logger = Rails.logger
        Rails.logger.level = :debug

        File.open(log_path("#{worker_name}.lock"), File::RDWR | File::CREAT, 0o644) do |fout|
          unless fout.flock(File::LOCK_EX | File::LOCK_NB)
            Rails.logger.warn("Another process already holds lock #{worker_name} (#{fout.read}), exiting...")
            break
          end

          fout.write("Locked by process ##{Process.pid} under process group ##{Process.ppid} at #{Time.now}")
          fout.flush
          yield
        end
      end

      def self.file_logger(worker_name)
        Logger.new(log_path("#{worker_name}.log"), LOG_FILES_TO_KEEP, LOG_FILE_SIZE)
      end

      def self.log_path(filename)
        Lab::Lims::Utils::LIMS_LOG_PATH.join(filename)
      end

      def self.realtime_updates_enabled?
        Lims::Config.updates_socket.key?('url')
      rescue Lab::Lims::Config::ConfigNotFound => e
        Rails.logger.warn("Check for realtime updates failed: #{e.message}")
        false
      end

      def self.lims_api
        Lab::Lims::ApiFactory.create_api
      end
    end
  end
end
