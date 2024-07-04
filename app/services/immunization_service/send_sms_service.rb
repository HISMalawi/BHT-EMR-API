# app/services/immunization_service/send_sms_service.rb
require 'net/http'
require 'uri'
require 'json'
require 'sidekiq'

module SendSmsService       
    include Sidekiq::Worker

    def self.perform_async(date, details) 
      @date = Date.parse(date)
      @details = details
      @converted_date = @date.strftime('%d-%B-%Y')
            
      message = "Okondweda #{@details[:firstname]} #{@details[:sirname]},\n" \
                "Mukukuziwitsidwa kuzabwelaso ku Chiptala\n" \
                "pa tsiku **#{@converted_date}**.\n" \
                "kut muzalandileso katemela.\n" \
                "Zikomo."

      uri = URI.parse("https://gateway.seven.io/api/sms")
      request = Net::HTTP::Post.new(uri)
      request["X-Api-Key"] = "c73C9ac143c557296F3E928f7b29ffB6da32473d93fa873e87Fb5521E1D7eBEB"
      request["Accept"] = "application/json"
      request.set_form_data(
        "to" => @details[:cell_phone],
        "from" => "IMMUNIZATION APP",
        "text" => message
      )

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Failed to send SMS"
      end

      response.body
    
    
  end
end
