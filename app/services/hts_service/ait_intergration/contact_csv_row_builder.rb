module HtsService::AitIntergration
  class ContactCsvRowBuilder

    def first_name contact
      "#{contact['Firstnames of contact']}#{contact['First name of contact']}"
    end

    def last_name contact
      "#{contact['Last name of contact']}#{contact['Lastname of contact']}"
    end

    def sex contact
      case contact['Gender of contact']&.strip
      when 'Male'
        'm'
      when 'Female'
        contact['Contact pregnancy status']&.strip&.downcase
      else contact['Gender of contact']&.strip&.downcase
      end
    end

    def contact_phone_number contact
      "#{contact['Contact phone number']}#{contact['Telephone number of contact']}"
    end

    def physical_address contact
      contact['Contact physical address']
    end

    def marital_status contact
      contact['Contact marital status']
    end

    def hiv_status contact
      "#{contact['Contact HIV tested']}#{contact['Contact has had HIV testing']}"&.downcase
    end

    def caseid contact
      nil
    end

    def parent_type contact
      'index'
    end

    def name contact
      "#{contact['Firstnames of contact']}#{contact['First name of contact']} #{contact['Last name of contact']}#{contact['Lastname of contact']}"
    end

    def contact_phone_number_verified contact
      0
    end

    def dob_known contact
      0
    end

    def age_format contact
      'years'
    end

    def sex_dissagregated contact
      sex contact
    end

    def entry_point contact
      'hts'
    end

    def age_in_years contact
      contact['Age of contact'].to_i
    end

    def age_in_months contact
      contact['Age of contact'].to_i * 12
    end

    def age contact
      contact['Age of contact'].to_i
    end

    def age_group contact
      age = contact['Age of contact'].to_i
      case age
      when 0..14
          '0-14 Years'
        when 15..24
          '15-24 Years'
        when 25..29
          '25-29 Years'
        when 30..Float::INFINITY
          '29+ Years'
        end
    end

    def dob contact
      (Date.today - contact['Age of contact'].to_i.years).change(day: 17)
    end

    def generation contact
      2
    end

    def close_case_date contact
      nil
    end

    def registered_by contact
      csv_row_builder.registered_by contact
    end

    def health_facility_id contact
      csv_row_builder.health_facility_id contact
    end

    def health_facility_name contact
      csv_row_builder.health_facility_name contact
    end

    def district_id contact
      csv_row_builder.district_id contact
    end

    def district_name contact
      csv_row_builder.district_name contact
    end

    def region_id contact
      csv_row_builder.region_id contact
    end

    def region_name contact
      csv_row_builder.region_name contact
    end

    def partner contact
      csv_row_builder.partner contact
    end

    def dhis2_code contact
      csv_row_builder.dhis2_code contact
    end

    def continue_registration contact
      1
    end

    def import_validation contact
      1
    end

    def site_id contact
      csv_row_builder.site_id contact
    end

    def owner_id contact
      csv_row_builder.owner_id contact
    end

    def relationship_with_index_adult contact
      contact['Relationships of contact']
    end

    
    def appointment_location contact
      contact['Contact appointment location']
    end

    def hiv_test_date contact
      contact['Contact HIV test date']
    end

    def ipv_status contact
      contact['IPV Status']
    end

    def village contact
      contact['Contact current village']
    end

    def traditional_authority contact
      contact['Contact current TA']
    end
    
    def select_recommended_mode_of_notification contact
      contact['Notification Means']&.downcase
    end
    
    def consent_to_contact contact
      contact['Consent to contact the contact']&.downcase ||= 'yes'
    end
    
    def referral_type contact
      contact['Referral type']
    end

    def appointment_date contact
      contact['Contact appointment date']&.to_date
    end

    def index_entry_point contact
      "hts"
    end


    private

    def csv_row_builder
      HtsService::AitIntergration::CsvRowBuilder.new
    end

  end
end