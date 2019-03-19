# frozen_string_literal: true

module ANCService
    # A summary of a patient's ART clinic visit
    class PatientVisit
      include ModelUtils
  
      attr_reader :patient, :date
  
      def initialize(patient, date)
        @patient = patient
        @date = date
      end

      def height
        @height ||= Observation.where(concept: concept('Height (cm)'), person: patient.person)
                      .order(obs_datetime: :desc)
                      .first.value_numeric rescue 0
      end
  
      def weight
        @weight ||= Observation.where(concept: concept('Weight'), person: patient.person)
                      .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                      .last
                      .value_numeric || 0
      end
  
      def bmi
        @bmi ||= calculate_bmi(weight, height)
      end

      def next_appointment
        Observation.where(person: patient.person, concept: concept('Appointment date'))\
                   .order(obs_datetime: :desc)\
                   .first\
                   &.value_datetime
      end

      def hiv_status
        current_status = ConceptName.find_by_name('HIV Status').concept_id
        prev_test_done = Observation.where( person: patient.person, concept: concept('Previous HIV Test Done'))\
            .order(obs_datetime: :desc)\
            .first\
            &.value_coded || nil
        if (prev_test_done == 1065) #if value is Yes, check prev hiv status
          prev_hiv_test_res = Observation.where(["person_id = ? and concept_id = ? and obs_datetime > ?",
             patient.person.id, ConceptName.find_by_name('Previous HIV Test Results').concept_id, date_of_lmp])\
            .order(obs_datetime: :desc)\
            .first\
            &.value_coded
          prev_status = ConceptName.find_by_concept_id(prev_hiv_test_res).name
          return prev_status if prev_status.to_s.downcase == 'positive'
        end

        hiv_test_res =  Observation.where(["person_id = ? and concept_id = ? and obs_datetime > ?",
             patient.person.id, ConceptName.find_by_name('HIV Status').concept_id, date_of_lmp])\
            .order(obs_datetime: :desc)\
            .first\
            &.value_coded rescue nil

        hiv_status = ConceptName.find_by_concept_id(hiv_test_res).name rescue nil
        
        hiv_status ||= prev_status

      end

      def pregnancy_test
        preg_test = Observation.where(["person_id = ? and concept_id = ? and obs_datetime > ?",
             patient.person.id, ConceptName.find_by_name('Pregnancy test').concept_id, date_of_lmp])\
            .order(obs_datetime: :desc)\
            .first\
            &.value_coded

        preg_test_status = ConceptName.find_by_concept_id(preg_test).name rescue 'Unk'
      end

      private

      def calculate_bmi(weight, height)
        return 'N/A' if weight.zero? || height.zero?

        (weight / (height * height) * 10_000).round(1)
      end

      def date_of_lmp
        last_lmp = patient.encounters.joins([:observations])
          .where(['encounter_type = ? AND obs.concept_id = ?',
            EncounterType.find_by_name('Current pregnancy').id,
            ConceptName.find_by_name('Last menstrual period').concept_id])
          .last.observations.collect { 
            |o| o.value_datetime 
          }.compact.last.to_date rescue nil
      end

    end
end