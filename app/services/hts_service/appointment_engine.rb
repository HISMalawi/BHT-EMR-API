module HTSService
  class AppointmentEngine
    include ModelUtils

    def initialize(program:, patient:, retro_date: Date.today)
      @ref_date = retro_date.respond_to?(:to_date) ? retro_date.to_date : date
      @program = program
      @patient = patient
    end

    def next_appointment_date
      return @ref_date + 2.weeks if has_inconclusive_hiv_result?
      return @ref_date + 4.weeks if is_high_risk_within_last_three_months?
      return @ref_date + 12.months if is_ongoing_risk?
      nil
    end

    def is_high_risk_within_last_three_months?
      Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('client risk category'),
        value_coded: concept('High risk event in last 3 months')
      ).where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      .exists?
    end

    def has_inconclusive_hiv_result?
      Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('HIV Status'),
        value_coded: concept('Inconclusive')
      ).where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      .exists?
    end

    def is_ongoing_risk?
      Observation.joins(:encounter).where(
        encounter: { type: encounter_type("Testing") },
        concept: concept('client risk category'),
        value_coded: concept('On-going risk')
      ).where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@ref_date))
      .exists?
    end
  end
end