# frozen_string_literal: true

module ARTService
  # Provides various data that is required for a transfer out note
  class PatientTransferOut
    include ModelUtils

    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def reason_for_art_eligibility
      patient_summary.art_reason
    end

    def who_clinical_conditions
      use_extended_staging_questions = global_property('use.extended.staging.questions')&.property_value

      encounter = hiv_staging_encounter
      return [] unless encounter

      encounter.observations.each_with_object([]) do |obs, conditions|
        if use_extended_staging_questions&.casecmp?('true') && obs.answer_string&.casecmp?('yes')
          conditions << obs.name
        elsif obs.name.casecmp?('Who Stages Criteria Present')
          conditions << obs.answer_string
        end
      end
    end

    def transferred_out_to
      concept_id = ConceptName.find_by_name('Transfer out to').concept_id
      Observation.where(concept_id: concept_id,
                        person_id: patient.patient_id)\
                 .last\
                 &.value_text
    end

    def cd4_count
      obs = hiv_staging_encounter.observations\
                                 .where(concept: concept('CD4 count'))\
                                 .last

      "#{obs&.value_modifier}#{obs&.value_numeric&.to_i}"
    end

    def cd4_count_date
      hiv_staging_encounter.observations\
                           .where(concept: concept('CD4 count date'))\
                           .last\
                           &.value_datetime\
                           &.to_date
    end

    def initial_weight
      initial_observation(concept('Weight (kg)'))&.value_numeric
    end

    def initial_height
      initial_observation(concept('Height (cm)'))&.value_numeric
    end

    def date_antiretrovirals_started
      patient_summary.art_period[0]
    end

    private

    def patient_summary
      ARTService::PatientSummary.new patient, date
    end

    def hiv_staging_encounter
      return @hiv_staging_encounter if @hiv_staging_encounter

      @hiv_staging_encounter = Encounter.where(type: encounter_type('HIV Staging'),
                                               patient: patient)\
                                        .order(encounter_datetime: :desc)\
                                        &.first
    end

    def initial_observation(concept)
      Observation.where(person_id: patient.patient_id, concept: concept)\
                 .order(obs_datetime: :desc)\
                 .first
    end
  end
end
