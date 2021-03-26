# frozen_string_literal: true

require 'logger_multiplexor'

Rails.logger = LoggerMultiplexor.new(Rails.root.join('log/lims-push.log'), $stdout)
api = Lab::Lims::Api.new
worker = Lab::Lims::Worker.new(api)

def with_lock(lock_file)
  File.open("log/#{lock_file}", File::RDWR | File::CREAT, 0o644) do |file|
    unless file.flock(File::LOCK_EX | File::LOCK_NB)
      Rails.logger.warn("Failed to start new process due to lock: #{lock_file}")
      exit 2
    end

    file.rewind
    file.puts("Process ##{Process.pid} started at #{Time.now}")

    yield
  end
end

case ARGV[0]&.downcase
when 'push'
  with_lock('lims-push.lock') { worker.push_orders }
when 'pull'
  with_lock('lims-pull.lock') { worker.pull_orders }
else
  warn 'Error: No or invalid action specified: Valid actions are push and pull'
  warn 'USAGE: rails runner start_worker.rb push'
  exit 1
end
