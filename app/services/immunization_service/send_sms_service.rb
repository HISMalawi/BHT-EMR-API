module ImmunizationService
  module SendSmsService
    def self.perform_async(date, details, action)
      config = load_config
      globalconfig = load_siteglobal_config

      if globalconfig.present?
        config.merge!(globalconfig)
      end
       
      case action
      when 'send_appointment'
        send_appointment_reminder(date, details, config)
      when 'cancel_appointment'
        cancel_appointment_reminder(date, details, config)
      end
    end

    def self.load_config
      config_file = Rails.root.join('config', 'application.yml')
      YAML.load_file(config_file)["eir_sms_configurations"][Rails.env] || {}
    end

    def self.load_siteglobal_config
      config = {}
      keys = [
        "next_appointment_reminder_period",
        "next_appointment_message", 
        "cancel_appointment_message",
        "sms_reminder",
        "sms_activation",
        "show_sms_popup"
      ]
      properties = GlobalProperty.where(property: keys.map { |key| "#{User.current.location_id}_#{key}" })
                                 .pluck(:property, :property_value)
                                 .to_h
      keys.each do |key|
        property_key = "#{User.current.location_id}_#{key}"
        config[key] = properties[property_key] || nil
      end
    
      config 
    end

    def self.send_appointment_reminder(date, details, config)
      return unless config["sms_reminder"] && config["sms_activation"]

      config_key = "#{User.current.location_id}_next_appointment_message"

      if config["next_appointment_reminder_period"] == 'Instant reminder'
        SendSmsJob.perform_later(date, details, config_key)
      else
        schedule_sms(date, details, config_key, config["next_appointment_reminder_period"])
      end
    end

    def self.schedule_sms(date, details, config_key, period)
      days_before = period.split(" ")[0].to_i
      reminder_date = Date.parse(date) - days_before
      reminder_time = reminder_date.to_time
      SendSmsJob.set(wait_until: reminder_time).perform_later(date, details, config_key)
    end

    def self.cancel_appointment_reminder(date, details, config)
      config_key = "#{User.current.location_id}_cancel_appointment_message"

      cancel_scheduled_sms(date, details)
       SendSmsJob.perform_later(date, details, config_key) if config['sms_activation']
    end

    def self.cancel_scheduled_sms(date, details)
      Sidekiq::ScheduledSet.new.each do |job|
        job_details = job.args.first
        if job_details['date'] == date && job_details['details'] == details
          job.delete
        end
      end
    end
  end
end