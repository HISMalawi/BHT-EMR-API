# frozen_string_literal: true

class AddVisitsReportType < ActiveRecord::Migration[5.2]
  def up
    ReportType.create name: 'visits',
                      creator: User.first.id,
                      date_created: Time.now
  rescue StandardError => e
    Rails.logger.error "Unhandled exception: #{e}"
  end

  def down
    ReportType.find_by_name('visits')&.delete
  rescue StandardError => e
    Rails.logger.error "Unhandled exception: #{e}"
  end
end
