# frozen_string_literal: true

module VMMCService
  # A summary of a patient's VMMC clinic visit
  class PatientVisit
    LOGGER = Rails.logger
    TIME_EPOCH = '1970-01-01'.to_time

    include ModelUtils

    attr_reader :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def outcome
      return @outcome if @outcome

      outcome = ActiveRecord::Base.connection.select_one(
        "SELECT patient_outcome(#{patient.id}, DATE('#{date.to_date}')) as outcome"
      )['outcome']

      @outcome = outcome.casecmp?('UNKNOWN') ? 'Not Available' : outcome
    end

    def outcome_date
      date
    end

    def next_appointment
      Observation.where(person: patient.person, concept: concept('Appointment date'))\
                 .order(obs_datetime: :desc)\
                 .first\
                 &.value_datetime
    end

    def circumcision_date
      Observation.where(person: patient.person, concept: concept('circumcision date'))\
                 .order(obs_datetime: :desc)\
                 .first\
                 &.value_datetime
    end

    def visit_by
      if patient_present? && guardian_present?
        'BOTH'
      elsif patient_present?
        'Patient'
      elsif guardian_present?
        'Guardian'
      else
        'Unk'
      end
    end
  end
end
