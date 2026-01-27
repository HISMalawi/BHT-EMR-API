class NcdActiveClientsJob
  include Sidekiq::Job
  sidekiq_options queue: :ncd_active_patients, retry: 3

  def perform(*args)
    Rails.logger.info("Starting NCD active patients sync")
    begin
      NcdActiveClientsFinderService.new.find_active_clients()
      Rails.logger.info("Successfully called find_active_clients method")
    rescue StandardError => e
      Rails.logger.error("Error syncing NCD active patients: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise # Re-raise to trigger Sidekiq retry mechanism
    end
  end
end