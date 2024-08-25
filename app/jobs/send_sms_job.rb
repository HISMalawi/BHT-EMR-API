class SendSmsJob < ApplicationJob
  queue_as :default

  def perform(date, details)
    @date = Date.parse(date)
    @details = details
    @converted_date = @date.strftime('%d-%B-%Y')
    facility_id = User.current.location_id
    
    sms_gateway_url = get_global_property("#{facility_id}_sms_gateway_url")
    sms_api_key = get_global_property("#{facility_id}_sms_api_key")
    next_appointment_message = get_global_property("#{facility_id}_next_appointment_message")

    sms_gateway_url ||= ENV['SMS_GATEWAY_URL']
    sms_api_key ||= ENV['SMS_API_KEY']
    next_appointment_message ||= ENV['NEXT_APPOINTMENT_MESSAGE']

    message = "#{next_appointment_message},\n" \
              "pa tsiku **#{@converted_date}**.\n"

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

  def get_global_property(property_name)
    GlobalProperty.find_by(property: property_name)&.property_value
  end
end
