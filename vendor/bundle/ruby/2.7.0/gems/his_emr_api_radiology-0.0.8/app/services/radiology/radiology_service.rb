# frozen_string_literal: true
require "net/ftp"
module Radiology
  module RadiologyService
    class << self

      def generate_msi(patient_details,physician_details, radiology_orders)
        orders =''
        radiology_orders.each do |order|
          if orders != ''
            orders = "#{order[:sub_value_text].gsub(' ', '_')} , #{orders}"
          else
            orders = order[:sub_value_text].gsub(' ', '_')
          end
        end
  
  
        sample_file_path = "#{Rails.root}/config/sample.msi"
        save_file_path = "/tmp/#{patient_details[:accession_number] }_#{patient_details[:patient_name].gsub(' ', '_')}_scheduled_radiology.msi"
  
        # using eval() might decrease performance, not sure if there's a better way to do this.
        msi_file_data = eval(File.read(sample_file_path))
  
        File.open(save_file_path, "w+") do |f|
          f.write(msi_file_data)
        end
        send_scheduled_msi("#{save_file_path}")
      end
  
       # send created msi file to ftp server
      def send_scheduled_msi(file_path)
        main_config = YAML.load_file("#{Rails.root}/config/application.yml")
        # connect with FTP server
        # NOTE: main_config[:ftp_host], main_config[:ftp_user_name], main_config[:ftp_pw] is in application.yml file.
        Net::FTP.open(main_config['ftp_host']) do |ftp|
          ftp.passive = true
          ftp.login(main_config['ftp_user_name'], main_config['ftp_pw'])
          ftp.putbinaryfile(file_path)
        end
      end
  
      def print_radiology_barcode(accession_number,patient_national_id_with_dashes, patient_name, radio_order,date_created)
        label = 'label' + 0.to_s
        label = ZebraPrinter::Label.new(500,165)
        label.font_size = 2
        label.font_horizontal_multiplier = 1
        label.font_vertical_multiplier = 1
        label.left_margin = 300
        label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
        label.draw_multi_text("#{patient_name} #{patient_national_id_with_dashes}")
        label.draw_multi_text("x-ray, #{radio_order.name.downcase rescue nil} - #{accession_number rescue nil}")
        label.draw_multi_text("#{date_created}")
  
        label.print(1)
      end
      
      def get_radiology_orders(group_concept_id)
        stats = []
        i = 0
    
        groupData = get_concept_names(group_concept_id)
        (groupData || []).each do |groupRecord|
          stats << {
            concept_id: groupRecord['concept_id'],
            group: groupRecord['name'],
            complaints: [],
          }
    
          data = get_concept_names(groupRecord['concept_id'])
          (data || []).each do |record|
            stats[i][:complaints] << {
              concept_id: record['concept_id'],
              name: record['name'],
            }
          end
    
          i += 1
        end
    
        stats
      end
    
      def get_concept_names(concept_id)
        ConceptName.where("s.concept_set = ?
        ", concept_id).joins("INNER JOIN concept_set s ON
        s.concept_id = concept_name.concept_id").group("concept_name.concept_id").order(:name)
      end

      def get_previous_orders(patient_id)
        Observation.where("person_id = ?  AND voided =0 AND concept_id = 8426",patient_id).order('obs_datetime DESC')
      end
    end
  end
end
