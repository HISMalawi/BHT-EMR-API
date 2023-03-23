module HTSService::AITIntergration
  class ContactCsvRowBuilder

    def caseid contact
      nil
    end

    def parent_type contact
      "index"
    end

    def name contact
      "#{contact['first_name']} #{contact['last_name']}"
    end

    def contact_phone_number_verified contact
      0
    end

    def dob_known contact
      0
    end

    def age_format contact
      "Years"
    end

    def sex_dissagregated contact
      case contact['sex'].strip
        when "M"
        "Male"
      when "FNP"
        "Female"
      when "FP"
        "Female"
      else contact['sex']
      end
    end

    def entry_point contact
      "HTS"
    end

    def age_in_years contact
      contact['age'].to_i
    end

    def age_in_months contact
      contact['age'].to_i * 12
    end

    def age contact
      contact['age'].to_i
    end

    def age_group contact
      age = contact['age'].to_i
      case age
      when 0..14
          "0-14 Years"
        when 15..24
          "15-24 Years"
        when 25..29
          "25-29 Years"
        when 30..Float::INFINITY
          "29+ Years"
        end
    end

    def dob contact
      (Date.today - contact['age'].to_i.years).change(day: 17)
    end

    def sex contact
      contact['sex'].strip
    end

    def generation contact
      csv_row_builder.generation contact
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


    private

    def csv_row_builder
      HTSService::AITIntergration::CsvRowBuilder.new
    end

  end
end