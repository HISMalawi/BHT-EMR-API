# frozen_string_literal: true

module ARTService
  # A card having a summary/snapshot of a patient's current
  # state and history
  class PatientSummaryLabel
    include ModelUtils

    def print(patient)
      demographics = mastercard_demographics(patient)
      hiv_staging = Encounter.where(type: encounter_type('HIV Staging'), patient: patient).last

      tb_within_last_two_yrs = 'tb within last 2 yrs' unless demographics.tb_within_last_two_yrs.blank?
      eptb = 'eptb' unless demographics.eptb.blank?
      pulmonary_tb = 'Pulmonary tb' unless demographics.pulmonary_tb.blank?

      cd4_count_date = nil; cd4_count = nil; pregnant = 'N/A'

      begin
        hiv_staging.observations.map do |obs|
          concept_name = obs&.to_s&.split(':')&.[](0)&.strip
          next if concept_name.blank?

          case concept_name
          when 'CD4 COUNT DATETIME'
            cd4_count_date = obs.value_datetime.to_date
          when 'CD4 COUNT'
            cd4_count = obs.value_numeric
          when 'IS PATIENT PREGNANT?'
            pregnant = obs&.to_s&.split(':')&.[](1)
          end
        end
      rescue StandardError
        []
      end

      office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
      home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
      cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

      begin
     phone_number = office_phone_number if !office_phone_number.casecmp('not available').zero? && !office_phone_number.casecmp('unknown').zero?
      rescue StandardError
        nil
   end
      begin
     phone_number = home_phone_number if !home_phone_number.casecmp('not available').zero? && !home_phone_number.casecmp('unknown').zero?
      rescue StandardError
        nil
   end
      begin
     phone_number = cell_phone_number if !cell_phone_number.casecmp('not available').zero? && !cell_phone_number.casecmp('unknown').zero?
      rescue StandardError
        nil
   end

      initial_height = PatientService.get_patient_attribute_value(patient, 'initial_height')
      initial_weight = PatientService.get_patient_attribute_value(patient, 'initial_weight')

      label = ZebraPrinter::StandardLabel.new
      label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}", 450, 300, 0, 1, 1, 1, false)
      label.draw_text(demographics.arv_number.to_s, 575, 30, 0, 3, 1, 1, false)
      label.draw_text('PATIENT DETAILS', 25, 30, 0, 3, 1, 1, false)
      label.draw_text("Name:   #{demographics.name} (#{demographics.sex})", 25, 60, 0, 3, 1, 1, false)
      label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}", 25, 90, 0, 3, 1, 1, false)
      label.draw_text("Phone: #{phone_number}", 25, 120, 0, 3, 1, 1, false)
      if (demographics.address.blank? ? 0 : demographics.address.length) > 48
        label.draw_text("Addr:  #{demographics.address[0..47]}", 25, 150, 0, 3, 1, 1, false)
        label.draw_text("    :  #{demographics.address[48..-1]}", 25, 180, 0, 3, 1, 1, false)
        last_line = 180
      else
        label.draw_text("Addr:  #{demographics.address}", 25, 150, 0, 3, 1, 1, false)
        last_line = 150
      end

      if !demographics.guardian.nil?
        if (last_line == 180) && (demographics.guardian.length < 48)
          label.draw_text("Guard: #{demographics.guardian}", 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif (last_line == 180) && (demographics.guardian.length > 48)
          label.draw_text("Guard: #{demographics.guardian[0..47]}", 25, 210, 0, 3, 1, 1, false)
          label.draw_text("     : #{demographics.guardian[48..-1]}", 25, 240, 0, 3, 1, 1, false)
          last_line = 240
        elsif (last_line == 150) && (demographics.guardian.length > 48)
          label.draw_text("Guard: #{demographics.guardian[0..47]}", 25, 180, 0, 3, 1, 1, false)
          label.draw_text("     : #{demographics.guardian[48..-1]}", 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif (last_line == 150) && (demographics.guardian.length < 48)
          label.draw_text("Guard: #{demographics.guardian}", 25, 180, 0, 3, 1, 1, false)
          last_line = 180
        end
      else
        if last_line == 180
          label.draw_text('Guard: None', 25, 210, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 180
          label.draw_text('Guard: None}', 25, 210, 0, 3, 1, 1, false)
          last_line = 240
        elsif last_line == 150
          label.draw_text('Guard: None', 25, 180, 0, 3, 1, 1, false)
          last_line = 210
        elsif last_line == 150
          label.draw_text('Guard: None', 25, 180, 0, 3, 1, 1, false)
          last_line = 180
        end
      end

      label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}", 25, last_line += 30, 0, 3, 1, 1, false)
      label.draw_text("FUP:   (#{demographics.agrees_to_followup})", 25, last_line += 30, 0, 3, 1, 1, false)

      label2 = ZebraPrinter::StandardLabel.new
      # Vertical lines
      label2.draw_line(25, 170, 795, 3)
      # label data
      label2.draw_text('STATUS AT ART INITIATION', 25, 30, 0, 3, 1, 1, false)
      label2.draw_text("(DSA:#{begin
                                  patient.date_started_art.strftime('%d-%b-%Y')
                               rescue StandardError
                                 'N/A'
                                end})", 370, 30, 0, 2, 1, 1, false)
      label2.draw_text(demographics.arv_number.to_s, 580, 20, 0, 3, 1, 1, false)
      label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}", 25, 300, 0, 1, 1, 1, false)

      label2.draw_text("RFS: #{demographics.reason_for_art_eligibility}", 25, 70, 0, 2, 1, 1, false)
      label2.draw_text("#{cd4_count} #{cd4_count_date}", 25, 110, 0, 2, 1, 1, false)
      label2.draw_text("1st + Test: #{demographics.hiv_test_date}", 25, 150, 0, 2, 1, 1, false)

      label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}", 380, 70, 0, 2, 1, 1, false)
      label2.draw_text("KS:#{begin
                                demographics.ks
                             rescue StandardError
                               nil
                              end}", 380, 110, 0, 2, 1, 1, false)
      label2.draw_text("Preg:#{pregnant}", 380, 150, 0, 2, 1, 1, false)
      label2.draw_text((begin
                             demographics.first_line_drugs.join(',')[0..32]
                        rescue StandardError
                          nil
                           end).to_s, 25, 190, 0, 2, 1, 1, false)
      label2.draw_text((begin
                             demographics.alt_first_line_drugs.join(',')[0..32]
                        rescue StandardError
                          nil
                           end).to_s, 25, 230, 0, 2, 1, 1, false)
      label2.draw_text((begin
                             demographics.second_line_drugs.join(',')[0..32]
                        rescue StandardError
                          nil
                           end).to_s, 25, 270, 0, 2, 1, 1, false)

      label2.draw_text("HEIGHT: #{initial_height}", 570, 70, 0, 2, 1, 1, false)
      label2.draw_text("WEIGHT: #{initial_weight}", 570, 110, 0, 2, 1, 1, false)
      label2.draw_text("Init Age: #{begin
                                       PatientService.patient_age_at_initiation(patient, demographics.date_of_first_line_regimen)
                                    rescue StandardError
                                      nil
                                     end}", 570, 150, 0, 2, 1, 1, false)

      line = 190
      extra_lines = []
      label2.draw_text('STAGE DEFINING CONDITIONS', 450, 190, 0, 3, 1, 1, false)

      begin
        (demographics.who_clinical_conditions.split(';') || []).each do |condition|
          line += 25
          if line <= 290
            label2.draw_text(condition[0..35], 450, line, 0, 1, 1, 1, false)
          end
          extra_lines << condition[0..79] if line > 290
        end
      rescue StandardError
        []
      end

      if (line > 310) && !extra_lines.blank?
        line = 30
        label3 = ZebraPrinter::StandardLabel.new
        label3.draw_text('STAGE DEFINING CONDITIONS', 25, line, 0, 3, 1, 1, false)
        label3.draw_text(PatientService.get_patient_identifier(patient, 'ARV Number').to_s, 370, line, 0, 2, 1, 1, false)
        label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}", 450, 300, 0, 1, 1, 1, false)
        begin
          extra_lines.each do |condition|
            label3.draw_text(condition, 25, line += 30, 0, 2, 1, 1, false)
          end
        rescue StandardError
          []
        end
      end
      return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" unless extra_lines.blank?

      "#{label.print(1)} #{label2.print(1)}"
 end
  end
end
