# frozen_string_literal: true

module AncService
  # A summary of a patient's ART clinic visit
  class PatientVisit
    include ModelUtils

    attr_reader :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def height
      @height ||= begin
        Observation.where(concept: concept('Height (cm)'), person: patient.person)
                   .order(obs_datetime: :desc)
                   .first.value_numeric
      rescue StandardError
        0
      end
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
      ConceptName.find_by_name('HIV Status').concept_id
      prev_test_done = Observation.where(person: patient.person, concept: concept('Previous HIV Test Done'))\
                                  .order(obs_datetime: :desc)\
                                  .first\
                                  &.value_coded || nil
      if prev_test_done == 1065 # if value is Yes, check prev hiv status
        prev_hiv_test_res = Observation.where(['person_id = ? and concept_id = ? and obs_datetime > ?',
                                               patient.person.id, ConceptName.find_by_name('Previous HIV Test Results').concept_id, date_of_lmp])\
                                       .order(obs_datetime: :desc)\
                                       .first\
                                       &.value_coded
        prev_status = ConceptName.find_by_concept_id(prev_hiv_test_res).name
        return prev_status if prev_status.to_s.downcase == 'positive'
      end

      hiv_test_res = begin
        Observation.where(['person_id = ? and concept_id = ? and obs_datetime > ?',
                           patient.person.id, ConceptName.find_by_name('HIV Status').concept_id, date_of_lmp])\
                   .order(obs_datetime: :desc)\
                   .first\
                   &.value_coded
      rescue StandardError
        nil
      end

      hiv_status = begin
        ConceptName.find_by_concept_id(hiv_test_res).name
      rescue StandardError
        nil
      end

      hiv_status || prev_status
    end

    def pregnancy_test
      preg_test = Observation.where(['person_id = ? and concept_id = ? and obs_datetime > ?',
                                     patient.person.id, ConceptName.find_by_name('Pregnancy test').concept_id, date_of_lmp])\
                             .order(obs_datetime: :desc)\
                             .first\
                             &.value_coded

      begin
        ConceptName.find_by_concept_id(preg_test).name
      rescue StandardError
        'Unk'
      end
    end

    def active_range(date)
      current_range = {}

      active_date = date

      pregnancies = {}

      # active_years = {}

      abortion_check_encounter = begin
        patient.encounters.where(['encounter_type = ? AND encounter_datetime > ? AND DATE(encounter_datetime) <= ?',
                                  EncounterType.find_by_name('PREGNANCY STATUS').encounter_type_id, date.to_date - 7.months, date.to_date]).order(['encounter_datetime DESC']).first
      rescue StandardError
        nil
      end

      aborted = begin
        abortion_check_encounter.observations.collect do |ob|
          ob.answer_string.downcase.strip if ob.concept_id == ConceptName.find_by_name('PREGNANCY ABORTED').concept_id
        end.compact.include?('yes')
      rescue StandardError
        false
      end

      date_aborted = begin
        abortion_check_encounter.observations.find_by_concept_id(ConceptName.find_by_name('DATE OF SURGERY').concept_id).answer_string
      rescue StandardError
        nil
      end
      recent_lmp = begin
        find_by_sql(["SELECT * from obs WHERE person_id = #{patient.id}
              AND concept_id = #{concept('DATE OF LAST MENSTRUAL PERIOD').concept_id}"]).last.answer_string.squish.to_date
      rescue StandardError
        nil
      end

      patient.encounters.order(['encounter_datetime DESC']).each do |e|
        next unless e.name == 'CURRENT PREGNANCY' && !pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')]

        pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')] = {}

        e.observations.each do |o|
          concept = ConceptName.find(o.concept_id)

          next unless concept

          if o.concept_id == begin
            concept('DATE OF LAST MENSTRUAL PERIOD').concept_id
          rescue StandardError
            nil
          end
            pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')]['DATE OF LAST MENSTRUAL PERIOD'] =
              o.answer_string.squish
          end

          next unless o.concept_id == begin
            concept('Estimated date of delivery').concept_id
          rescue StandardError
            nil
          end

          pregnancies[e.encounter_datetime.strftime('%Y-%m-%d')]['EXPECTED DATE OF DELIVERY'] =
            o.answer_string.squish
          # end
        end
      end

      # pregnancies = pregnancies.delete_if{|x, v| v == {}}

      # raise pregnancies.inspect

      pregnancies.each do |preg|
        date_of_lmp = preg[1]['DATE OF LAST MENSTRUAL PERIOD']

        date_of_delivery = preg[1]['EXPECTED DATE OF DELIVERY']

        @end_date = date_of_delivery.blank? ? date_of_lmp.to_date + 9.month : date_of_delivery.to_date

        if preg[1]['DATE OF LAST MENSTRUAL PERIOD']
          preg[1]['START'] = preg[1]['DATE OF LAST MENSTRUAL PERIOD'].to_date
          preg[1]['END'] = @end_date # 45.week # + 7.day + 45.week # 9.month
        else
          preg[1]['START'] = preg[0].to_date
          preg[1]['END'] = preg[0].to_date + 9.month # 45.week # 7.day + 45.week # 9.month
        end

        if active_date >= preg[1]['START'] && active_date <= preg[1]['END']
          current_range['START'] = preg[1]['START']
          current_range['END'] = preg[1]['END']
        end
      end

      if recent_lmp.present?
        current_range['START'] = recent_lmp
        current_range['END'] = current_range['END'] # + 45.week # + 7.day + 45.week #+ 9.months
      end

      if begin
        abortion_check_encounter.present? && aborted && date_aborted.present? && current_range['START'].to_date < date_aborted.to_date
      rescue StandardError
        false
      end

        current_range['START'] = date_aborted.to_date + 10.days
        current_range['END'] = current_range['END'] # + 45.week # + 7.day + 45.week #+ 9.months
      end

      current_range['END'] = current_range['END'] unless begin
        (current_range['END']).to_date.blank?
      rescue StandardError
        true
      end

      [current_range, pregnancies]
    end

    private

    def calculate_bmi(weight, height)
      return 'N/A' if weight.zero? || height.zero?

      (weight / (height * height) * 10_000).round(1)
    end

    def date_of_lmp
      patient.encounters.joins([:observations])
             .where(['encounter_type = ? AND obs.concept_id = ?',
                     EncounterType.find_by_name('Current pregnancy').id,
                     ConceptName.find_by_name('Last menstrual period').concept_id])
             .last.observations.collect(&:value_datetime).compact.last.to_date
    rescue StandardError
      nil
    end
  end
end
