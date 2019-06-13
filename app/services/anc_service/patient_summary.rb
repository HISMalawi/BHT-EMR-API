# frozen_string_literal: true

module ANCService
  # Provides various summary statistics for an ART patient
  class PatientSummary
    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    attr_reader :patient
    attr_reader :date

    def initialize(patient, date)
      @patient = patient
      @date = date
      @art_service = ARTService::PatientSummary
      @patient_visit = PatientVisit.new(patient,date)
    end

    def full_summary
      active_range = @patient_visit.active_range(@date)
      gest_age = ((@date.to_date - active_range[0]["START"].to_date).to_i / 7) - 1 rescue nil
      edod = active_range[0]["END"].to_date rescue nil
      {
        patient_id: patient.patient_id,
        current_outcome: getCurrentPatientOutcome,
        date_of_lnmp: date_of_lnmp,
        anc_visits: number_of_visits,
        fundus: fundus,
        gestation: gest_age,
        edod: edod
      }
    end

    def date_of_lnmp
      last_lmp = patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ?',
          EncounterType.find_by_name('Current pregnancy').id,
          ConceptName.find_by_name('Last menstrual period').concept_id])
        .last.observations.collect {
          |o| o.value_datetime
        }.compact.last.to_date rescue nil

    end

    def number_of_visits
      lmp_date = date_of_lnmp

      visits = []

      anc_visits = patient.encounters.joins([:observations])
        .where(['encounter_type = ? AND obs.concept_id = ?
            AND encounter_datetime > ?',
          EncounterType.find_by_name('ANC Visit Type').id,
          ConceptName.find_by_name('Reason for visit').concept_id,
          lmp_date]).each do |e|
        e.observations.each do |o|
          visits << o.value_numeric unless o.value_numeric.blank?
        end
      end
      return visits.length
    end

    def fundus
      lmp_date = date_of_lnmp
      fundus = patient.encounters.joins([:observations])
        .where(["encounter_type = ? AND obs.concept_id = ?
            AND encounter_datetime > ?",
          EncounterType.find_by_name('Current pregnancy').id,
          ConceptName.find_by_name('week of first visit').concept_id,
          lmp_date])
        .last.observations.collect {|o|
          o.value_numeric
        }.compact.last.to_i rescue nil
    end

    def getCurrentPatientOutcome
      state = ActiveRecord::Base.connection.select_one(
        "SELECT state FROM patient_state INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id
        AND p.program_id = 12 WHERE (patient_state.voided = 0 AND p.voided = 0
          AND p.program_id = program_id AND DATE(start_date) <= '#{@date}'
          AND p.patient_id = #{@patient.id})
          AND (patient_state.voided = 0)
          ORDER BY start_date DESC, patient_state.patient_state_id DESC,
          patient_state.date_created DESC LIMIT 1;"
      )["state"] rescue nil

      return "Unknown" if state.blank?

      outcome = ActiveRecord::Base.connection.select_one(
        "SELECT name FROM program_workflow_state INNER JOIN concept_name ON concept_name.concept_id = program_workflow_state.concept_id
        WHERE program_workflow_state_id = '#{state}';"
      )["name"]

    end

  end
end