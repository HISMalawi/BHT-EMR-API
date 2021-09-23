# frozen_string_literal: true

module ARTService
  class VLReminder
    attr_reader :patient, :program, :date

    def initialize(patient_id:, date: nil)
      @program = Program.find_by_name('HIV PROGRAM')
      @patient = Patient.find(patient_id)
      @date = date&.to_date || Date.today
    end

    ##
    # Checks if patient is due for Viral load.
    #
    # See: #find_patient_viral_load_due_date
    def patient_due_for_viral_load?
      find_patient_viral_load_due_date >= date
    end

    ##
    # Returns patient's viral load due date.
    #
    # How it works:
    #   1. Find patient's recent viral load in the last 12 months
    #   2. If patient does not have have a viral load goto 3 else goto 4
    #   3. If patient *has been on ART* beyond 6 months then the patient is due else the patient isn't due
    #   4. Find a regimen switch due to treatment failure after the recent viral load
    #   5. If patient does not have a regimen switch goto 6 else goto 7
    #   6. Patient is not due for viral load (hasn't been 12 months since last VL)
    #   7. If time elapsed since regimen switch at least 6 months then patient is due else patient isn't due
    def find_patient_viral_load_due_date
      viral_load = find_patient_recent_viral_load # Search defaults to last 12 months
      unless viral_load
        # If patient doesn't have a viral load in the last 12 months then we know that
        # the patient might be due but we need to verify that we aren't dealing with
        # a newly initiated patient (these are due after 6 months on ART). And if we
        # determine that the patient is indeed due we need to make sure that at no
        # point in the last 12 months did the patient decide to skip the viral load.
        viral_load_due_date = patient_earliest_start_date + 6.months
        return viral_load_due_date if viral_load_due_date > date

        viral_load_skip = find_patient_recent_viral_load_skip
        return viral_load_skip.obs_datetime.to_date + 6.months if viral_load_skip

        viral_load = find_patient_last_viral_load
        return viral_load ? viral_load.start_date.to_date + 12.months : Date.today
      end

      # If patient has a viral load in the last 12 months then we need to make sure
      # that the patient didn't have a regimen switch after the viral load due to
      # a treatment failure.
      regimen_switch = find_patient_recent_regimen_switch(last_viral_load_date: viral_load.start_date.to_date)
      return viral_load.start_date.to_date + 12.months unless regimen_switch

      # The patient did indeed switch regimens, now we need to check if 6 months hasn't
      # elapsed since the regimen switch. If it has then we need to make sure there isn't
      # a viral load skip after that.
      viral_load_due_date = regimen_switch.obs_datetime.to_date + 6.months
      return viral_load_due_date if viral_load_due_date < date

      viral_load_skip = find_patient_recent_viral_load_skip(duration: date - regimen_switch.obs_datetime.to_date)
      viral_load_due_date = viral_load_skip + 6.months
      return viral_load_due_date if viral_load_skip

      regimen_switch.obs_datetime.to_date + 6.months
    end

    ##
    # Returns patient's latest viral load order within specified duration to now.
    #
    # Parameters:
    #   duration: An ActiveSupport::Duration specifying the period to search for a viral load
    #             starting from set date going back (default: 12 months)
    def find_patient_recent_viral_load(duration: 12.months)
      Lab::LabOrder.where(concept: ConceptName.where(name: 'Blood').select(:concept_id), patient: patient)
                   .where('start_date BETWEEN DATE(?) AND DATE(?)', (date - duration), date)
                   .joins(:tests)
                   .merge(viral_load_tests)
                   .order(:start_date)
                   .last
    end

    ##
    # Returns patient's last viral load before now
    def find_patient_last_viral_load
      Lab::LabOrder.where(concept: ConceptName.where(name: 'Blood').select(:concept_id), patient: patient)
                   .where('start_date <= DATE(?)', date)
                   .joins(:tests)
                   .merge(viral_load_tests)
                   .order(:start_date)
                   .last
    end

    def viral_load_tests
      Observation.where(concept: ConceptName.where(name: 'Test type').select(:concept_id),
                        value_coded: ConceptName.where(name: 'Viral Load').select(:concept_id))
    end

    ##
    # Returns patient's latest regimen switch within the specified duration to now.
    #
    # Parameters:
    #    duration: An ActiveSupport::Duration specifying the period to search for the regimen
    #              switch from set date going back (default: 6 months)
    #    last_viral_load_date: When provided this can be used to widen the search scope above
    #                          the duration
    def find_patient_recent_regimen_switch(duration: 6.months, last_viral_load_date: nil)
      start_date = date - duration
      start_date = last_viral_load_date if last_viral_load_date && last_viral_load_date < start_date

      regimen_switch_concept = ConceptName.where(name: 'Reason antiretrovirals substitute or switch (first line only)')
                                          .select(:concept_id)
      Observation.where(concept: regimen_switch_concept, person_id: patient.patient_id, value_text: 'Treatment failure')
                 .where('obs_datetime BETWEEN DATE(?) AND DATE(?)', start_date, date)
                 .order(:obs_datetime)
                 .last
    end

    ##
    # Returns the most recent viral load skip in the last specified period.
    def find_patient_recent_viral_load_skip(duration: 6.months)
      Observation.where(concept: ConceptName.where(name: ['Delayed milestones', 'Tests ordered'])
                                            .select(:concept_id),
                        person_id: patient.patient_id)
                 .where('obs_datetime BETWEEN DATE(?) AND (?)', date - duration, date)
                 .order(:obs_datetime)
                 .last
    end

    ##
    # Checks if patient has a skipped viral load in period between last viral load due_date and now.
    def patient_skipped_viral_load?(due_date)
      # Shouldn't we be looking for value_coded: concept('Yes') or something?
      Observation.where(concept: ConceptName.where(name: ['Delayed milestones', 'Tests ordered'])
                                            .select(:concept_id),
                        person_id: patient.patient_id)
                 .where('obs_datetime BETWEEN DATE(?) AND (?)', due_date, date)
                 .exists?
    end

    def vl_reminder_info
      due_date = find_patient_viral_load_due_date
      return struct_vl_info(eligible: true) if due_date <= date

      days_to_go = due_date - date
      if in_months(days_to_go) < 9.months
        return struct_vl_info(eligible: false, message: "Viral load due in #{days_to_go.to_i} days")
      end

      last_viral_load = find_patient_last_viral_load
      last_viral_load_skip = find_patient_recent_viral_load_skip

      if last_viral_load_skip && last_viral_load && last_viral_load_skip.obs_datetime.to_date > last_viral_load_skip
        return struct_vl_info(
          eligible: true,
          message: "Viral load set for next milestone by #{provider(last_viral_load_skip.creator)}"
        )
      end

      if last_viral_load
        return struct_vl_info(
          eligible: false,
          message: "Viral load ordered on #{last_viral_load.strftime('%d/%b/%Y')} by #{provider(last_viral_load.creator)}"
        )
      end

      struct_vl_info(
        eligible: false,
        message: "Viral load not due until #{due_date}"
      )
    end

    private

    def in_months(date_diff)
      (date_diff.to_i.days / 31.days).months
    end

    def patients_service
      ARTService::PatientsEngine.new
    end

    def patient_earliest_start_date
      return @patient_earliest_start_date if @patient_earliest_start_date

      date_enrolled = patients_service.find_patient_date_enrolled(patient)
      @patient_earliest_start_date = patients_service.find_patient_earliest_start_date(patient, date_enrolled)&.to_date
      @patient_earliest_start_date ||= PatientProgram.find_by(patient: patient, program: @program).date_enrolled
      raise ApplicationError, 'Patient is not on ART' unless @patient_earliest_start_date

      @patient_earliest_start_date
    end

    def struct_vl_info(eligible: false, skip_milestone: false, message: nil)
      {
        milestone: nil,
        eligibile: eligible,  # Not fixing eligibile[sic] to maintain original interface
        period_on_art: period_on_art_in_months, # months_on_art,
        earliest_start_date: patient_earliest_start_date,
        skip_milestone: skip_milestone,
        message: message,
        # current_regimen: {
        #   regimen: patient_current_regimen,
        #   date_started: :string
        # },
        # previous_regimen: {
        #   regimen: patient_current_regimen(find_patient_recent_regimen_switch(duration: 12.months)),
        #   date_completed: :date
        # }
      }
    end

    def find_patient_current_regimen(date = nil)
      ARTService::PatientSummary.new(patient, date || self.date).current_regimen
    end

    def period_on_art_in_months
      (@date.year * 12 + @date.month) - (patient_earliest_start_date.year * 12 + patient_earliest_start_date.month)
    end

  end
end
