# frozen_string_literal: true

module AncService
  class DashboardStatsQueries
    include ModelUtils

    LOGGER = Rails.logger
    ANC_ENROLLMENT_ENCOUNTER_TYPE_ID = 237.freeze

    def new_and_continuing_anc_clients
      return 0 if anc_program_id.nil?
      count, source = if anc_enrollment_encounter_type_id.present?
        [count_by_anc_enrollment_encounter, 'encounter']
      else
        [count_by_patient_program, 'patient_program']
      end
      LOGGER.info "[ANC DashboardStatsQueries] new_and_continuing_anc_clients count=#{count} source=#{source}"
      count
    end

    private

    def anc_program_id
      @anc_program_id ||= Program.find_by(name: 'ANC PROGRAM')&.id
    end

    def anc_enrollment_encounter_type_id
      @anc_enrollment_encounter_type_id ||= ANC_ENROLLMENT_ENCOUNTER_TYPE_ID
    end

    def count_by_anc_enrollment_encounter
      Encounter.where(
        program_id: anc_program_id,
        encounter_type: anc_enrollment_encounter_type_id,
        voided: 0
      ).distinct
       .count(:patient_id)
    end

    def count_by_patient_program
      PatientProgram.where(
        program_id: anc_program_id,
        voided: 0
      ).count(:patient_id)
    end
  end
end
