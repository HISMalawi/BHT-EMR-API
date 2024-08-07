# frozen_string_literal: true

module Lab
  module ResultsService
    class << self
      ##
      # Attach results to a test
      #
      # Params:
      #   test_id: The tests id (maps to obs_id of the test's observation in OpenMRS)
      #   params: A hash comprising the following fields
      #     - encounter_id: Encounter to create result under (can be ommitted but provider_id has to specified)
      #     - provider_id: Specify a provider for an encounter the result is going to be created under
      #     - date: Retrospective date when the result was received (can be ommitted, defaults to today)
      #     - measures: An array of measures. A measure is an object of the following structure
      #         - indicator: An object that has a concept_id field (concept_id of the indicator)
      #         - value_type: An enum that's limited to 'numeric', 'boolean', 'text', and 'coded'
      def create_results(test_id, params)
        ActiveRecord::Base.transaction do
          test = Lab::LabTest.find(test_id)
          encounter = find_encounter(test, encounter_id: params[:encounter_id],
                                           date: params[:date]&.to_date,
                                           provider_id: params[:provider_id])

          results_obs = create_results_obs(encounter, test, params[:date], params[:comments])
          params[:measures].map { |measure| add_measure_to_results(results_obs, measure, params[:date]) }

          Lab::ResultSerializer.serialize(results_obs)
        end
      end

      private

      def find_encounter(test, encounter_id: nil, date: nil, provider_id: nil)
        return Encounter.find(encounter_id) if encounter_id

        Encounter.create!(
          patient_id: test.person_id,
          program_id: test.encounter.program_id,
          type: EncounterType.find_by_name!(Lab::Metadata::ENCOUNTER_TYPE_NAME),
          encounter_datetime: date || Date.today,
          provider_id: provider_id || User.current.user_id
        )
      end

      # Creates the parent observation for results to which the different measures are attached
      def create_results_obs(encounter, test, date, comments = nil)
        void_existing_results_obs(encounter, test)

        Lab::LabResult.create!(
          person_id: encounter.patient_id,
          encounter_id: encounter.encounter_id,
          concept_id: test_result_concept.concept_id,
          order_id: test.order_id,
          obs_group_id: test.obs_id,
          obs_datetime: date&.to_datetime || DateTime.now,
          comments: comments
        )
      end

      def void_existing_results_obs(encounter, test)
        result = Lab::LabResult.find_by(person_id: encounter.patient_id,
                                        concept_id: test_result_concept.concept_id,
                                        obs_group_id: test.obs_id)
        return unless result

        result.measures.map { |child_obs| child_obs.void("Updated/overwritten by #{User.current.username}") }
        result.void("Updated/overwritten by #{User.current.username}")
      end

      def test_result_concept
        ConceptName.find_by_name!(Lab::Metadata::TEST_RESULT_CONCEPT_NAME)
      end

      def add_measure_to_results(results_obs, params, date)
        validate_measure_params(params)

        Observation.create!(
          person_id: results_obs.person_id,
          encounter_id: results_obs.encounter_id,
          order_id: results_obs.order_id,
          concept_id: params[:indicator][:concept_id],
          obs_group_id: results_obs.obs_id,
          obs_datetime: date&.to_datetime || DateTime.now,
          **make_measure_value(params)
        )
      end

      def validate_measure_params(params)
        raise InvalidParameterError, 'measures.value is required' if params[:value].blank?

        if params[:indicator]&.[](:concept_id).blank?
          raise InvalidParameterError, 'measures.indicator.concept_id is required'
        end

        params
      end

      # Converts user provided measure values to observation_values
      def make_measure_value(params)
        obs_value = { value_modifier: params[:value_modifier] }
        value_type = params[:value_type] || 'text'

        case value_type.downcase
        when 'numeric' then obs_value.merge(value_numeric: params[:value])
        when 'boolean' then obs_value.merge(value_boolean: parse_boolen_value(params[:value]))
        when 'coded' then obs_value.merge(value_coded: params[:value]) # Should we be collecting value_name_coded_id?
        when 'text' then obs_value.merge(value_text: params[:value])
        else raise InvalidParameterError, "Invalid value_type: #{params[:value_type]}"
        end
      end

      def parse_boolen_value(string)
        case string.downcase
        when 'true' then true
        when 'false' then false
        else raise InvalidParameterError, "Invalid boolean value: #{string}"
        end
      end
    end
  end
end
