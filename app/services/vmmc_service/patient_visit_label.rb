# frozen_string_literal: true

module VmmcService
  class PatientVisitLabel
    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def print
      visit = VmmcService::PatientVisit.new patient, date
      return unless visit

      label = ZebraPrinter::StandardLabel.new
      label.draw_text(seen_by(patient, date).to_s, 597, 250, 0, 1, 1, 1, false)
      label.draw_text(date&.strftime('%B %d %Y').upcase, 25, 30, 0, 3, 1, 1, false)
      label.draw_text(patient.national_id.to_s, 565, 30, 0, 3, 1, 1, true)
      label.draw_text("#{patient.person.name}(#{patient.gender})", 25, 60, 0, 3, 1, 1, false)
      label.draw_text(date&.strftime('%B %d %Y').upcase, 25, 30, 0, 3, 1, 1, false)
      label.draw_text('Date of MC: ' + (visit.circumcision_date&.strftime('%d/%b/%Y') || 'Not Available'), 25, 95, 0, 2, 1, 1, false)
      label.draw_text('Appointment', 255, 130, 0, 3, 1, 1, false)
      label.draw_text('OUTC', 577, 130, 0, 3, 1, 1, false)
      label.draw_line(25, 150, 800, 5)
      label.draw_text(visit.outcome.to_s, 577, 160, 0, 2, 1, 1, false)
      label.draw_text(visit.outcome_date&.strftime('%d/%b/%Y') || 'N/A', 655, 130, 0, 2, 1, 1, false)
      unless visit.next_appointment.blank?
        label.draw_text('Next Appointment Date: ' + visit.next_appointment&.strftime('%d/%b/%Y'), 110, 160, 0, 2, 1, 1, false)
      end
      starting_index = 25
      start_line = 160

      label.print(2)
    end

    def seen_by(patient, date = Date.today)
      encounter_type = EncounterType.find_by_name('REGISTRATION CONSENT').id
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
        clinic_encounters = ['REGISTRATION CONSENT', 'UPDATE HIV STATUS', 'MEDICAL HISTORY', 'CIRCUMCISION', 'GENITAL EXAMINATION', 'SUMMARY ASSESSMENT']
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
  end
end
