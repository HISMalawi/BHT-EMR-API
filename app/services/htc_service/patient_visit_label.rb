# frozen_string_literal: true

module ARTService
  class PatientVisitLabel
    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def print
      visit = ARTService::PatientVisit.new patient, date
      return unless visit

      owner = visit.guardian_present? && !visit.patient_present? ? ' :Guardian Visit' : ' :Patient visit'

      arv_number = patient.identifier('ARV Number')&.identifier || patient.national_id

      label = ZebraPrinter::StandardLabel.new
      # label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
      label.draw_text(seen_by(patient, date).to_s, 597, 250, 0, 1, 1, 1, false)
      label.draw_text(date&.strftime('%B %d %Y').upcase, 25, 30, 0, 3, 1, 1, false)
      label.draw_text(arv_number.to_s, 565, 30, 0, 3, 1, 1, true)
      label.draw_text("#{patient.person.name}(#{patient.gender}) #{owner}", 25, 60, 0, 3, 1, 1, false)
      label.draw_text(('(' + visit.visit_by + ')' unless visit.visit_by.blank?).to_s, 255, 30, 0, 2, 1, 1, false)

      pill_count = visit.pills_brought.collect { |c| c.join(',') }&.join(' ')
      label.draw_text("#{visit.height.to_s + 'cm' unless visit.height.blank?}  #{visit.weight.to_s + 'kg' unless visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s unless visit.bmi.blank?} VL:#{visit.viral_load_result} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}", 25, 95, 0, 2, 1, 1, false)

      label.draw_text('SE', 25, 130, 0, 3, 1, 1, false)
      label.draw_text('TB', 110, 130, 0, 3, 1, 1, false)
      label.draw_text('Adh', 185, 130, 0, 3, 1, 1, false)
      label.draw_text('DRUG(S) GIVEN', 255, 130, 0, 3, 1, 1, false)
      label.draw_text('OUTC', 577, 130, 0, 3, 1, 1, false)
      label.draw_line(25, 150, 800, 5)
      label.draw_text(visit.tb_status.to_s, 110, 160, 0, 2, 1, 1, false)
      label.draw_text(adherence_to_show(visit.adherence)&.gsub('%', '\\\\%').to_s, 185, 160, 0, 2, 1, 1, false)
      label.draw_text(visit.outcome.to_s, 577, 160, 0, 2, 1, 1, false)
      label.draw_text(visit.outcome_date&.strftime('%d/%b/%Y') || 'N/A', 655, 130, 0, 2, 1, 1, false)
      unless visit.next_appointment.blank?
        label.draw_text('Next: ' + visit.next_appointment&.strftime('%d/%b/%Y'), 577, 190, 0, 2, 1, 1, false)
      end
      starting_index = 25
      start_line = 160

      visit_extras(visit).each do |key, values|
        data = values&.last

        next if data.blank?

        bold = false
        # bold = true if key.include?("side_eff") and data !="None"
        # bold = true if key.include?("arv_given")
        starting_index = values.first.to_i
        starting_line = start_line
        starting_line = start_line + 30 if key.include?('2')
        starting_line = start_line + 60 if key.include?('3')
        starting_line = start_line + 90 if key.include?('4')
        starting_line = start_line + 120 if key.include?('5')
        starting_line = start_line + 150 if key.include?('6')
        starting_line = start_line + 180 if key.include?('7')
        starting_line = start_line + 210 if key.include?('8')
        starting_line = start_line + 240 if key.include?('9')
        next if starting_index.zero?

        label.draw_text(data.to_s, starting_index, starting_line, 0, 2, 1, 1, bold)
      end

      label.print(2)
    end

    def seen_by(patient, date = Date.today)
      encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
      a = Encounter.find_by_sql("SELECT * FROM encounter WHERE encounter_type = '#{encounter_type}'
                                  AND patient_id = #{patient.id}
                                  AND encounter_datetime between '#{date} 00:00:00'
                                  AND '#{date} 23:59:59'
                                  ORDER BY date_created DESC")
      provider = begin
                  [a.first.name, a.first.creator]
                 rescue StandardError
                   nil
                end
      # provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'HIV CLINIC CONSULTATION' ; [e.name,e.creator]}.compact
      provider_username = ('Seen by: ' + User.find(provider[1]).username).to_s unless provider.blank?
      if provider_username.blank?
        clinic_encounters = ['HIV CLINIC CONSULTATION', 'HIV STAGING', 'ART ADHERENCE', 'TREATMENT', 'DISPENSION', 'HIV RECEPTION']
        encounter_type_ids = EncounterType.where(['name IN (?)', clinic_encounters]).collect(&:id)
        encounter = Encounter.where(['patient_id = ? AND encounter_type In (?)', patient.id, encounter_type_ids]).order('encounter_datetime DESC').first
        provider_username = begin
                              ('Seen by: ' + User.find(encounter.creator).username).to_s
                            rescue StandardError
                              nil
                            end
      end
      provider_username
    end

    def adherence_to_show(adherence_data)
      # For now we will only show the adherence of the drug with the lowest/highest adherence %
      # i.e if a drug adherence is showing 86% and their is another drug with an adherence of 198%,then
      # we will show the one with 198%.
      # in future we are planning to show all available drug adherences

      adherence_to_show = 0
      adherence_over_100 = 0
      adherence_below_100 = 0
      over_100_done = false
      below_100_done = false

      adherence_data.each do |_drug, adh|
        next if adh.blank?

        drug_adherence = adh.to_i
        if drug_adherence <= 100
          adherence_below_100 = adh.to_i if adherence_below_100 == 0
          adherence_below_100 = adh.to_i if drug_adherence <= adherence_below_100
          below_100_done = true
        else
          adherence_over_100 = adh.to_i if adherence_over_100 == 0
          adherence_over_100 = adh.to_i if drug_adherence >= adherence_over_100
          over_100_done = true
        end
      end

      return if !over_100_done && !below_100_done

      over_100 = 0
      below_100 = 0
      over_100 = adherence_over_100 - 100 if over_100_done
      below_100 = 100 - adherence_below_100 if below_100_done

      return "#{adherence_over_100}%" if (over_100 >= below_100) && over_100_done

      "#{adherence_below_100}%"
    end

    def visit_extras(visit)
      return unless visit

      data = {}

      count = 1
      visit.side_effects.each do |side_eff|
        data["side_eff#{count}"] = '25', side_eff[0..5]
        count += 1
      end

      count = 1
      visit.pills_dispensed.each do |drug, pills|
        string = "#{drug} (#{strip_insignificant_zeroes(pills)})"
        if string.length > 26
          line = string[0..25]
          line2 = string[26..-1]
          data["arv_given#{count}"] = '255', line
          data["arv_given#{count += 1}"] = '255', line2
        else
          data["arv_given#{count}"] = '255', string
        end
        count += 1
      end

      visit_cpt = visit.cpt || 0
      data["arv_given#{count}"] = '255', "CPT (#{visit_cpt})" unless visit_cpt.zero?

      data
    end

    # Strip insignificant zeroes from a floating point number.
    #
    # Can save at least two characters which on a 255 character-wide
    # zebra printer can be a big plus!
    def strip_insignificant_zeroes(float)
      float.to_s.gsub(/\.0*$/, '')
    end
  end
end
