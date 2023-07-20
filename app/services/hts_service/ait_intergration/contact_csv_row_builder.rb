module HTSService::AITIntergration
  class ContactCsvRowBuilder

    def first_name contact, index
      "#{contact['Firstnames of contact']}#{contact['First name of contact']}"
    end

    def last_name contact, index
      "#{contact['Last name of contact']}#{contact['Lastname of contact']}"
    end

    def sex contact, index
      contact['Gender of contact']
    end

    def contact_phone_number contact, index
      "#{contact['Contact phone number']}#{contact['Telephone number of contact']}"
    end

    def physical_address contact, index
      contact['Contact physical address']
    end

    def marital_status contact, index
      contact['Contact marital status']
    end

    def hiv_status contact, index
      "#{contact['Contact HIV tested']}#{contact['Contact has had HIV testing']}"
    end

    def caseid contact, index
      nil
    end

    def parent_type contact, index
      'index'
    end

    def name contact, index
      "#{contact['Firstnames of contact']}#{contact['First name of contact']} #{contact['Last name of contact']}#{contact['Lastname of contact']}"
    end

    def contact_phone_number_verified contact, index
      0
    end

    def dob_known contact, index
      0
    end

    def age_format contact, index
      'Years'
    end

    def sex_dissagregated contact, index
      case contact['Gender of contact']&.strip
        when 'M'
        'Male'
      when 'FNP'
        'Female'
      when 'FP'
        'Female'
      else contact['Gender of contact']
      end
    end

    def entry_point contact, index
      'HTS'
    end

    def age_in_years contact, index
      contact['Age of contact'].to_i
    end

    def age_in_months contact, index
      contact['Age of contact'].to_i * 12
    end

    def age contact, index
      contact['Age of contact'].to_i
    end

    def age_group contact, index
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

    def dob contact, index
      (Date.today - contact['Age of contact'].to_i.years).change(day: 17)
    end

    def sex contact, index
      contact['Gender of contact'].strip
    end

    def generation contact, index
      2
    end

    def close_case_date contact, index
      nil
    end

    def registered_by contact, index
      csv_row_builder.registered_by contact
    end

    def health_facility_id contact, index
      csv_row_builder.health_facility_id contact
    end

    def health_facility_name contact, index
      csv_row_builder.health_facility_name contact
    end

    def district_id contact, index
      csv_row_builder.district_id contact
    end

    def district_name contact, index
      csv_row_builder.district_name contact
    end

    def region_id contact, index
      csv_row_builder.region_id contact
    end

    def region_name contact, index
      csv_row_builder.region_name contact
    end

    def partner contact, index
      csv_row_builder.partner contact
    end

    def dhis2_code contact, index
      csv_row_builder.dhis2_code contact
    end

    def continue_registration contact, index
      1
    end

    def import_validation contact, index
      1
    end

    def site_id contact, index
      csv_row_builder.site_id contact
    end

    def owner_id contact, index
      csv_row_builder.owner_id contact
    end

    def relationship_with_index_adult contact, index
      contact['Relationships of contact']
    end

    
    def appointment_location contact, index
      contact['Contact appointment location']
    end

    def hiv_test_date contact, index
      contact['Contact HIV test date']
    end

    def ipv_status contact, index
      contact['IPV Status']
    end

    def village contact, index
      contact['Contact current village']
    end

    def traditional_authority contact, index
      contact['Contact current TA']
    end
    
    def select_recommended_mode_of_notification contact, index
      contact['Notification Means']&.downcase
    end
    
    def consent_to_contact contact, index
      contact['Consent to contact the contact']
    end
    
    def referral_type contact, index
      contact['Referral type']
    end

    def appointment_date contact, index
      contact['Contact appointment date']&.to_date
    end


    private

    def csv_row_builder
      HTSService::AITIntergration::CsvRowBuilder.new
    end

  end
end