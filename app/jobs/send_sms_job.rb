class SendSmsJob < ApplicationJob
  queue_as :default

  def perform(date, details)      

    @date = Date.parse(date)
    @details = details
    @converted_date = @date.strftime('%d-%B-%Y')

   message = "#{ENV['NEXT_APPOINTMENT_MESSAGE']},\n" \
              "pa tsiku **#{@converted_date}**.\n" \
              
    uri = URI.parse(ENV['SMS_GATEWAY_URL'])
    request = Net::HTTP::Post.new(uri)
    request["X-Api-Key"] = ENV['SMS_API_KEY']
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

end