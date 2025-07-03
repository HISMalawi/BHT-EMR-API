# /config/initializers/solid_queue.rb

module SilenceHeartbeat
  def heartbeat
    ActiveRecord::Base.logger.silence do
      # Clear any previous changes before locking, for example, in case a previous heartbeat
      # failed because of a DB issue (with SQLite depending on configuration, a BusyException
      # is not rare) and we still have the unpersisted value
      restore_attributes
      with_lock { touch(:last_heartbeat_at) }
    end
  end
end

Rails.application.config.to_prepare do
  SolidQueue::Process.prepend(SilenceHeartbeat) unless Rails.env.production?
end

system('rails streaming:setup') unless SolidQueue::Job.table_exists?