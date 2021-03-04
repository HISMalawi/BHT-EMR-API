# frozen_string_literal: true

module ARTService
  class VLReminder
    attr_reader :patient, :program, :date

    def initialize(patient_id:, date: nil)
      @program = Program.find_by_name('HIV PROGRAM')
      @patient = Patient.find(patient_id)
      @date = date&.to_date || Date.today
    end

    def vl_reminder_info
      return struct_vl_info(eligible: true) if due_for_viral_load?

      days_to_go = next_viral_load_due_date - Date.today
      if in_months(days_to_go) < 9.months
        return struct_vl_info(eligible: false, message: "Viral load due in #{days_to_go.to_i} days")
      end

      provider_string = last_viral_load_provider ? " by #{last_viral_load_provider}" : ''

      if last_viral_load.value_coded == tests_ordered_concept_id
        return struct_vl_info(eligible: true, message: "Viral load set for next milestone#{provider_string}")
      end

      struct_vl_info(eligible: true,
                     message: "Viral load ordered on #{last_viral_load_date.strftime('%d/%b/%Y')}#{provider_string}")
    rescue ApplicationError => e
      Rails.logger.warn(`Checking for Viral Load milestone on patient ##{patient.id} failed: #{e.class} - #{e}`)
      {}
    end

    private

    def due_for_viral_load?
      due_for_initial_viral_load? || due_for_follow_up_viral_load?
    end

    ##
    # Checks if patient is due for the initial viral load after starting new medication.
    #
    # This applies to new patients or patients who have recently switched regimens.
    # If the patients haven't had a viral within 6 months since starting the
    # medication then they are due for viral load.
    def due_for_initial_viral_load?
      return months_elapsed_since(earliest_start_date) >= 6.months unless last_viral_load_date

      last_viral_load_date < last_regimen_switch_date && months_elapsed_since(last_regimen_switch_date) >= 6.months
    end

    def due_for_follow_up_viral_load?
      return false unless last_viral_load_date

      months_elapsed_since(last_viral_load_date) >= 12.months
    end

    def months_elapsed_since(date)
      in_months(Date.today - date)
    end

    def earliest_start_date
      return @earliest_start_date if @earliest_start_date

      date_enrolled = patients_service.find_patient_date_enrolled(patient)
      @earliest_start_date = patients_service.find_patient_earliest_start_date(patient, date_enrolled)&.to_date
      raise ApplicationError, 'Patient is not on ART' unless @earliest_start_date

      @earliest_start_date
    end

    def months_on_art
      @months_on_art ||= in_months(Date.today - earliest_start_date&.to_date)
    end

    def last_viral_load
      @last_viral_load ||= Observation.where(concept_id: ConceptName.where(name: 'HIV Viral Load')
                                                                    .select(:concept_id),
                                             value_coded: ConceptName.where(name: ['Delayed milestones', 'Tests ordered']),
                                             person_id: patient.patient_id)
                                      .where('obs_datetime < ?', date)
                                      .order(:obs_datetime)
                                      .last
    end

    def last_viral_load_date
      @last_viral_load_date ||= last_viral_load&.obs_datetime&.to_date
    end

    def next_viral_load_due_date
      return earliest_start_date + 6.months if last_viral_load_date.nil?

      base_date = [last_viral_load_date, last_regimen_switch_date].compact.max

      return base_date + 6.months if base_date == last_regimen_switch_date

      base_date + 12.months
    end

    def last_regimen_switch
      @last_regimen_switch ||=
        Observation.where(concept_id: ConceptName.where(name: 'Reason antiretrovirals substitute or switch (first line only)')
                                                 .select(:concept_id),
                          person_id: patient.patient_id)
                   .where('obs_datetime < ?', date)
                   .order(:obs_datetime)
                   .last
    end

    def patients_service
      @patients_service ||= ARTService::PatientsEngine.new(program: program)
    end

    def in_months(date_diff)
      (date_diff.to_i.days / 31.days).months
    end

    def struct_vl_info(milestone: nil, eligible: false, skip_milestone: false, message: nil)
      {
        milestone: milestone || months_elapsed_since(last_viral_load_date || earliest_start_date),
        eligibile: eligible,  # Not fixing eligibile[sic] to maintain original interface
        period_on_art: months_on_art,
        earliest_start_date: earliest_start_date,
        skip_milestone: skip_milestone,
        message: message
      }
    end
  end
end
