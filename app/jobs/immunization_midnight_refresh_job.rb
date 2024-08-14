class ImmunizationMidnightRefreshJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    start_date = 1.year.ago.to_date.to_s
    end_date = Date.today.to_s

    ImmunizationCacheDatum.pluck(:location_id).each do |location_id|
      ImmunizationReportJob.perform_later(start_date, end_date, location_id)
    end
  end
end
