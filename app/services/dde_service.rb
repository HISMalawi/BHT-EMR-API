# frozen_string_literal: true

class DDEService
  def re_assign_npid(dde_patient_id)
    dde_client.post '/assign_npid', doc_id: dde_patient_id
  end

  private

  def dde_client
    return @dde_client if @dde_client

    @dde_client = DDEClient.new

    logger.debug 'Searching for a stored DDE connection'
    connection = Rails.application.config.dde_connection

    if connection
      logger.debug 'Stored DDE connection found'
      @dde_client.connect connection: connection
      return
    end

    logger.debug 'No stored DDE connection found... Loading config...'
    Rails.application.config.dde_connection = @dde_client.connect(config: config)
  end

  def config
    app_config = YAML.load_file DDE_CONFIG_PATH
    {
      username: app_config['dde_username'],
      password: app_config['dde_password'],
      base_url: app_config['dde_url']
    }
  end
end
