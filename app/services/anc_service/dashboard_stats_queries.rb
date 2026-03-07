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

    def women_with_ultrasound_scanning
      return 0 if anc_program_id.nil?
      count = count_women_with_ga_by_ultrasound
      LOGGER.info "[ANC DashboardStatsQueries] women_with_ultrasound_scanning count=#{count}"
      count
    end

    def proportion_women_ultrasound_scanning
      total = new_and_continuing_anc_clients
      return 0.0 if total.zero?
      (women_with_ultrasound_scanning.to_f / total).round(4)
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

    def count_women_with_ga_by_ultrasound
      gestation_concept_id = ConceptName.find_by(name: 'Gestation age to be used')&.concept_id
      ga_ultrasound_concept_id = ConceptName.find_by(name: 'GA by ultrasound')&.concept_id
      
      return 0 if gestation_concept_id.nil?
      scope = Observation.joins(:encounter)
                         .where(encounter: { program_id: anc_program_id, voided: 0 })
                         .where(voided: 0, concept_id: gestation_concept_id)

      if ga_ultrasound_concept_id.present?
        scope = scope.where(
          'obs.value_text = ? OR obs.value_coded = ?',
          'GA by ultrasound',
          ga_ultrasound_concept_id
        )
      else
        scope = scope.where('obs.value_text = ?', 'GA by ultrasound')
      end

      scope.distinct.count(:person_id)
    end
  end
end
