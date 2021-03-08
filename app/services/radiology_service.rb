require "net/ftp"
module RadiologyService
  class << self
    def create_radiology_orders(patient_details,physician_details, radiology_orders)
      accession_number = patient_details[:accession_number]
      patientDOB = patient_details[:patientDOB]
      patient_info = patient_details
      current_user = physician_details[:userID]
      orders =''
      radiology_orders.each do |order|
        if orders != ''
          orders = "#{order[:sub_value_text].gsub(' ', '_')} , #{orders}"
        else
          orders = order[:sub_value_text].gsub(' ', '_')
        end
      end
      [orders]
      generate_msi(accession_number, patientDOB, patient_info, current_user, orders)
    end

    def generate_msi(accession_number, birthdate, patient_info, user_id, order)
      patient_name = "#{patient_info[:given_name]} #{patient_info[:family_name]}"
      study_id = accession_number
      sample_file_path = "/var/www/BHT-EMR-API/config/sample.msi"
      save_file_path = "/tmp/#{study_id }_#{patient_name.gsub(' ', '_')}_scheduled_radiology.msi"

      # using eval() might decrease performance, not sure if there's a better way to do this.
      msi_file_data = eval(File.read(sample_file_path))

      File.open(save_file_path, "w+") do |f|
        f.write(msi_file_data)
      end
      send_scheduled_msi("#{save_file_path}")
    end

     # send created msi file to ftp server
    def send_scheduled_msi(file_path)
      main_config = YAML.load_file('config/application.yml')
      # connect with FTP server
      # NOTE: main_config[:ftp_host], main_config[:ftp_user_name], main_config[:ftp_pw] is in application.yml file.
      Net::FTP.open(main_config['ftp_host']) do |ftp|
        ftp.passive = true
        ftp.login(main_config['ftp_user_name'], main_config['ftp_pw'])
        ftp.putbinaryfile(file_path)
      end
    end
  end
end
