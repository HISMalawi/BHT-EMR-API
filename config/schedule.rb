# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Runs script in bin/ using rails runner
every 1.minute do
  runner 'bin/lab/sync_worker.rb', environment: 'development'
end


every 1.day, at: ['4:30 am', '12:30 pm'] do
  runner 'bin/idsr/idsr_ohsp_monthly_report.rb', environment: 'development'
  runner 'bin/idsr/idsr_ohsp_weekly_report.rb',  environment: 'development'
end
every 1.minute do
  runner 'bin/idsr/notifiable_disease_conditions_report.rb', environment: 'development'
end