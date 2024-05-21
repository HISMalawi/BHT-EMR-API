# frozen_string_literal: true

module TbService
  class PatientVisitLabel
    include ModelUtils

    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
      @program = get_program
    end

    def get_visit_short_drug_list(drugs)
        drug_list = drugs.map { |drug, pills| "#{drug.delete(' ')}(#{pills})"}
        drug_list.each_slice(3).to_a
    end

    def print
      visit = TbService::PatientVisit.new patient, date
      return unless visit

      tb_number = patient.identifier('District TB Number')&.identifier || patient.identifier('District IPT Number')&.identifier || patient.national_id

      label = ZebraPrinter::Lib::StandardLabel.new
      # label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
      label.draw_text(seen_by(patient, date).to_s, 499, 255, 0, 1, 1, 1, false)
      label.draw_text(date&.strftime('%B %d %Y').upcase, 25, 30, 0, 3, 1, 1, false)
      label.draw_text(tb_number.to_s, 470, 30, 0, 3, 1, 1, true)
      label.draw_text("#{patient.person.name}(#{patient.gender})", 25, 60, 0, 3, 1, 1, false)

      pill_count = visit.pills_brought.collect { |c| c.join(',') }&.join(' ')
      label.draw_text(
        "#{visit.height.to_s + 'cm' unless visit.height.blank?}  #{visit.weight.to_s + 'kg' unless visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s unless visit.bmi.blank?} VL:#{visit.viral_load_result} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}", 25, 95, 0, 2, 1, 1, false
      )

      label.draw_text('SE', 25, 130, 0, 3, 1, 1, false)
      label.draw_text('TB', 110, 130, 0, 3, 1, 1, false)
      label.draw_text('Adh', 185, 130, 0, 3, 1, 1, false)
      label.draw_text('DRUG(S) GIVEN', 255, 130, 0, 3, 1, 1, false)
      label.draw_text('OUTC', 577, 130, 0, 3, 1, 1, false)
      label.draw_line(25, 150, 800, 5)
      label.draw_text(adherence_to_show(visit.adherence)&.gsub('%', '\\\\%').to_s, 25, 160, 0, 2, 1, 1, false)
      label.draw_text("#{visit.patient_outcome.name[0..20]}...", 499, 160, 0, 2, 1, 1, false)
      label.draw_text(visit.patient_outcome.start_date.nil? ? 'N/A' : visit.patient_outcome.start_date.strftime('%d/%b/%Y'), 600, 130, 0, 2, 1, 1, false)
      start_y_for_drugs = 160

      # Because MDR may contain so many drugs, we'll shorten the name of drugs to fit them in one line if possible.
      # This should be improved though, first line must support this as well at some point..
      if visit.patient_outcome.name == 'Multi drug resistance treatment'
        drug_list = get_visit_short_drug_list(visit.pills_dispensed)
        drug_list.each do |drugs|
          label.draw_text(drugs.join(', '), 110, start_y_for_drugs, 0, 2, 1, 1, false)
          start_y_for_drugs += 25
        end
      else
        visit.pills_dispensed.each do |drug, pills|
          label.draw_text("#{drug} (#{pills})", 110, start_y_for_drugs, 0, 2, 1, 1, false)
          start_y_for_drugs += 25
        end
      end
      label.draw_text('Next: ' + visit.next_appointment, 499, 230, 0, 2, 1, 1, false)
      label.print(2)
    end

    def seen_by(patient, date = Date.today)
      encounter_type = EncounterType.find_by_name('TB_Initial').id
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
        clinic_encounters = ['HIV CLINIC CONSULTATION', 'HIV STAGING', 'ART ADHERENCE', 'TREATMENT', 'DISPENSION',
                             'HIV RECEPTION']
        encounter_type_ids = EncounterType.where(['name IN (?)', clinic_encounters]).collect(&:id)
        encounter = Encounter.where(['patient_id = ? AND encounter_type In (?)', patient.id,
                                     encounter_type_ids]).order('encounter_datetime DESC').first
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

    private

    def get_program
      ipt? ? program('IPT Program') : program('TB Program')
    end

    def ipt?
      PatientProgram.joins(:patient_states)\
                    .where(patient_program: { patient_id: @patient,
                                              program_id: program('IPT Program') },
                           patient_state: { end_date: nil })\
                    .exists?
    end
  end
end
