# frozen_string_literal: true

require 'rake'

namespace :streaming do
  def print_streaming_stats(extra = {})
    jobs_done = SolidQueue::ClaimedExecution.count
    jobs_failed = SolidQueue::FailedExecution.count
    jobs_pending = SolidQueue::ReadyExecution.count
    jobs_scheduled = SolidQueue::ScheduledExecution.count

    puts ""
    puts "=== Streaming Stats ==="
    extra.each { |label, value| puts "  #{label}:".ljust(26) + value.to_s }
    puts "  Jobs done:".ljust(26) + jobs_done.to_s
    puts "  Jobs failed:".ljust(26) + jobs_failed.to_s
    puts "  Jobs pending:".ljust(26) + jobs_pending.to_s
    puts "  Jobs scheduled:".ljust(26) + jobs_scheduled.to_s
    puts "========================"
    puts ""
  end

  desc "Setup streaming"
  task setup: :environment do

    # set database to primary to prevent rails from using queue database
    # when running rake tasks
    system("export DATABASE=primary")

    # verify queue config has been setup in database.yml
    unless Rails.configuration.database_configuration[Rails.env]['queue']
      puts "Please setup queue config in database.yml"
      puts "See database.yml.example for details on queue configuration" 
      exit 1
    end

    # copy queue.yml and recurring.yml example files if not already
    unless File.exist?(Rails.root.join('config', 'queue.yml'))
      FileUtils.cp Rails.root.join('config', 'queue.yml.example'), Rails.root.join('config', 'queue.yml')
      
      puts "Copied queue.yml and recurring.yml example files to config directory."
    end

    unless File.exist?(Rails.root.join('config', 'recurring.yml'))
      FileUtils.cp Rails.root.join('config', 'recurring.yml.example'), Rails.root.join('config', 'recurring.yml')

      puts "Copied queue.yml and recurring.yml example files to config directory."
    end

    # check for queue configs in application.yml
    unless YAML.load_file(Rails.root.join('config', 'application.yml'))['cdr']
      puts "Please setup queue config in application.yml"
      puts "See application.yml.example for details on cdr key configuration" 
      exit 1
    end

    # check if queue database exists, if not create it
    ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1' if Rails.env.production?

    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "queue").configuration_hash

    abort "Missing 'queue' DB config under #{Rails.env} in database.yml" unless config

    ActiveRecord::Tasks::DatabaseTasks.create(config)

    # dump force the file, use raw commands
    system("mysql -u #{config[:username]} -p#{config[:password]} -h #{config[:host]} -P #{config[:port]} #{config[:database]} < #{Rails.root.join('db', 'sql', 'solid_queue_schema.sql')}  -f")
    
    # Enable Streaming in Global Properties
    use_db = <<~SQL
      USE #{Rails.configuration.database_configuration[Rails.env]['primary']['database']};
    SQL
    query = <<~SQL
      INSERT INTO global_property (uuid, property, property_value, description)
      VALUES (UUID(), 'patient.streaming', 'active', 'Enable/Disable patient streaming')
      ON DUPLICATE KEY UPDATE property_value = 'active';
    SQL
    ActiveRecord::Base.connection.execute(use_db)
    ActiveRecord::Base.connection.execute(query)

    # success message
    puts "\e[32mStreaming setup successfully\e[0m"
  
  rescue => e
    puts "\e[31mStreaming setup failed\e[0m"
    puts e.message
  end

  desc "Stream incomplete visits for a date range. Usage: rails streaming:incomplete start_date=YYYY-MM-DD end_date=YYYY-MM-DD"
  task incomplete: :environment do
    start_date = ENV['start_date']
    end_date = ENV['end_date']

    if start_date.blank? || end_date.blank?
      puts "\e[31mError: start_date and end_date are required.\e[0m"
      puts "Usage: rails streaming:incomplete start_date=YYYY-MM-DD end_date=YYYY-MM-DD"
      exit 1
    end

    begin
      start_date = Date.parse(start_date)
      end_date = Date.parse(end_date)
    rescue Date::Error => e
      puts "\e[31mError: Invalid date format - #{e.message}\e[0m"
      puts "Dates must be in YYYY-MM-DD format."
      exit 1
    end

    # Set a current user — required by WorkflowEngine for loading user activities
    User.current = User.first
    unless User.current
      puts "\e[31mError: No users found in the database.\e[0m"
      exit 1
    end

    puts "Fetching incomplete visits from #{start_date} to #{end_date}..."

    results = ArtService::DataCleaningTool.new(
      start_date: start_date,
      end_date: end_date,
      tool_name: 'INCOMPLETE VISITS'
    ).results

    if results.is_a?(String)
      puts "\e[31mData cleaning tool error: #{results}\e[0m"
      exit 1
    end

    if results.blank?
      puts "\e[33mNo incomplete visits found for the given date range.\e[0m"
      exit 0
    end

    puts "Found #{results.keys.length} patients with incomplete visits."

    jobs_enqueued = 0

    begin
      ActiveRecord::Base.establish_connection(:queue)

      results.each do |patient_id, details|
        details[:dates].each do |date|
          StreamingJob.perform_later(
            patient_id: patient_id,
            program_id: 1,
            date: date.to_date.strftime('%Y-%m-%d')
          )
          jobs_enqueued += 1
        end
      end

      print_streaming_stats('Jobs enqueued (this run)' => jobs_enqueued)
      puts "\e[32mStreaming incomplete visits completed successfully.\e[0m"
    rescue => e
      puts "\e[31mStreaming incomplete visits failed: #{e.message}\e[0m"
    ensure
      ActiveRecord::Base.establish_connection(:primary)
    end
  end

  desc "Re-stream all failed jobs from SolidQueue. Usage: rails streaming:failed"
  task failed: :environment do
    begin
      ActiveRecord::Base.establish_connection(:queue)

      failed_executions = SolidQueue::FailedExecution.includes(:job).all

      if failed_executions.empty?
        puts "\e[33mNo failed jobs found.\e[0m"
        next
      end

      puts "Found #{failed_executions.count} failed jobs. Retrying..."

      failed_jobs = failed_executions.map(&:job)
      SolidQueue::FailedExecution.retry_all(failed_jobs)

      print_streaming_stats('Jobs retried' => failed_jobs.size)
      puts "\e[32mFailed jobs retry completed successfully.\e[0m"
    rescue => e
      puts "\e[31mFailed jobs retry failed: #{e.message}\e[0m"
    ensure
      ActiveRecord::Base.establish_connection(:primary)
    end
  end

  desc "Show current SolidQueue streaming stats. Usage: rails streaming:stats"
  task stats: :environment do
    begin
      ActiveRecord::Base.establish_connection(:queue)
      print_streaming_stats
    rescue => e
      puts "\e[31mFailed to fetch streaming stats: #{e.message}\e[0m"
    ensure
      ActiveRecord::Base.establish_connection(:primary)
    end
  end

  desc "Check CDR configuration and ping the CDR URL. Usage: rails streaming:ping"
  task ping: :environment do
    cdr_config = YAML.load_file(Rails.root.join('config', 'application.yml'))['cdr']

    unless cdr_config
      puts "\e[31mError: CDR configuration not found in application.yml.\e[0m"
      puts "Add a 'cdr' section with url, username, and password."
      exit 1
    end

    url = cdr_config['url']
    username = cdr_config['username']
    password = cdr_config['password']

    puts "=== CDR Configuration ==="
    puts "  URL:      #{url}"
    puts "  Username: #{username}"
    puts "  Password: #{'*' * password.to_s.length}"
    puts "========================="
    puts ""

    %w[url username password].each do |key|
      next if cdr_config[key].present?

      puts "\e[31mError: '#{key}' is missing from CDR configuration.\e[0m"
      exit 1
    end

    puts "Pinging #{url}..."

    require 'net/http'
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    request.body = '{}'
    response = http.request(request)

    if response.code.to_i < 400
      puts "\e[32mResponse: #{response.code} #{response.message} — CDR is reachable.\e[0m"
    elsif response.code.to_i >= 500
      puts "\e[32mCDR is reachable.\e[0m"
    else
      puts "\e[33mResponse: #{response.code} #{response.message}\e[0m"
    end
  rescue Errno::ECONNREFUSED
    puts "\e[31mConnection refused — CDR server is not running at #{url}\e[0m"
  rescue Net::OpenTimeout, Net::ReadTimeout
    puts "\e[31mTimeout — CDR server at #{url} did not respond within 10 seconds.\e[0m"
  rescue SocketError => e
    puts "\e[31mDNS/Network error — #{e.message}\e[0m"
  rescue => e
    puts "\e[31mFailed to ping CDR: #{e.message}\e[0m"
  end
end