# frozen_string_literal: true

module OpdService
  class LabEngine
    attr_reader :program

    def initialize(program:)
      @program = program
    end

    def malaria_orders(params)
      patient = Patient.find(params[:patient_id])

      lab_orders_encounter_type_id = EncounterType.find_by_name('LAB ORDERS').encounter_type_id
      tests_ordered_concept_id = Concept.find_by_name('BLOOD').concept_id

      lab_result_encounter_type_id = EncounterType.find_by_name('LAB RESULTS').encounter_type_id
      malaria_test_result_concept_id = Concept.find_by_name('MALARIA TEST RESULT').concept_id

      available_options = []
      tests_ordered = Observation.find_by_sql("SELECT o.* FROM encounter e INNER JOIN obs o
          ON e.encounter_id = o.encounter_id AND e.encounter_type = #{lab_orders_encounter_type_id}
          AND o.concept_id = #{tests_ordered_concept_id} AND o.person_id = '#{patient.patient_id}'
          AND e.voided=0 ORDER BY e.encounter_datetime DESC LIMIT 10")

      tests_ordered.each do |test_obs|
        accession_number = test_obs.accession_number
        test_name = test_obs.answer_string.squish
        obs_datetime = test_obs.obs_datetime.to_date.strftime('%Y-%m-%d')

        test_result = Observation.find_by_sql("SELECT o.* FROM encounter e INNER JOIN obs o
          ON e.encounter_id = o.encounter_id AND e.patient_id = #{patient.id} AND e.encounter_type = #{lab_result_encounter_type_id}
          AND o.concept_id = #{malaria_test_result_concept_id} AND o.accession_number = '#{accession_number}'
          AND e.voided=0")

        next unless test_result.blank? # Interested only in orders with no results

        # ["Accession #: 202011 Test: Microscopy Date: 2016-05-16", "Microscopy:202011"]
        option = ["Accession #: #{accession_number} Test: #{test_name} Date: #{obs_datetime}", "#{test_name}:#{accession_number}"]
        available_options << option
      end

      available_options
    end
  end
end
