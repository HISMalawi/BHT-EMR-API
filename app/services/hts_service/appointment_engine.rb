module HTSService
  class AppointmentEngine
    include ModelUtils

    def initialize(program:, patient:, retro_date: Date.today)
      @ref_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
      @program = program
      @patient = patient
    end

    def concept_id(name)
      concept(name).concept_id
    end

    def next_appointment_date
      inconclusive_concept = 10609
      hiv_status = recent_hiv_status
      return @ref_date + 2.weeks if recent_access_point == concept_id('Community') && hiv_status == concept_id('Positive')
      return @ref_date + 2.weeks if hiv_status == inconclusive_concept
      if hiv_status == concept_id('Negative')
        risk_category = recent_risk_category
        return @ref_date + 4.weeks if risk_category == concept_id('High risk event in last 3 months')
        return @ref_date + 12.months if risk_category == concept_id('On-going risk')
      end
    end

    def recent_hiv_status
      obs = Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('HIV status'),
        person: @patient.person,
      ).where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      return obs.first.value_coded if obs.exists?
    end

    def recent_access_point
      obs = Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('HTS Access Type'),
        person: @patient.person,
      ).where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      return obs.first.value_coded if obs.exists?
    end

    def recent_risk_category
      obs = Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('client risk category'),
        person: @patient.person,
      ).where('encounter_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      return obs.first.value_coded if obs.exists?
    end
  end
end
