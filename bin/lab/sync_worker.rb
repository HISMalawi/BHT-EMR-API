# frozen_string_literal: true

##
# Rails runner script that runs/manages processes that push/pull data to/from LIMS.

# Get the version of his_emr_api_lab gem
gem_version = Gem::Specification.find_by_name('his_emr_api_lab').version

# Set the start date for syncing orders. This is necessary to prevent syncing of orders that are too old and may have already been synced in previous runs.
# The minimum date is set to 2025-10-01 to ensure that we do not sync orders that are too old, while also allowing for a reasonable window of time for syncing recent orders.
# The start date is calculated as the maximum of 180 days ago and the minimum date, ensuring that we do not sync orders that are older than 180 days or before the minimum date.
minimum_date = Date.parse('2025-10-01')
sixty_days_ago = Date.today - 180.days
start_date = [sixty_days_ago, minimum_date].max.to_s

# Check if version is greater than 2.1.8.4
if gem_version > Gem::Version.new('2.1.8.4')
  Lab::Lims::Worker.start(start_date: start_date)
else
  Lab::Lims::Worker.start
end
