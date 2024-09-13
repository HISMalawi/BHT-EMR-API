class SendSmsJob < ApplicationJob
  queue_as :default

  def perform(date, details, key)
    config = load_config
    @date = Date.parse(date)
    @details = details
    @converted_date = @date.strftime('%d-%B-%Y')
    
    sms_gateway_url = config["sms_gateway_url"]
        sms_api_key = config["sms_api_key"]
    appointment_message = get_global_property(key)
    
    message = "#{appointment_message},\n" \
              "**#{@converted_date}**.\n"

    uri = URI.parse(sms_gateway_url)
    request = Net::HTTP::Post.new(uri)
    request["X-Api-Key"] = sms_api_key
    request["Accept"] = "application/json"
    request.set_form_data(
      "to" => @details[:cell_phone],
      "from" => "IMMUNIZATION APP",
      "text" => message
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Failed to send SMS" unless response.is_a?(Net::HTTPSuccess)
    response.body

  end

  private

  def load_config
    config_file = Rails.root.join('config', 'application.yml')
    YAML.load_file(config_file)["eir_sms_configurations"][Rails.env] || {}
  end

  def get_global_property(property_name)
    GlobalProperty.find_by(property: property_name)&.property_value
  end
end