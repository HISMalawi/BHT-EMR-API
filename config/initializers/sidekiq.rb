# config/initializers/sidekiq.rb
Sidekiq.default_worker_options = { 'retry' => true } # Retry indefinitely

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

  