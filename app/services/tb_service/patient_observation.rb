module TbService::PatientObservation
  class << self
    include ModelUtils

    def get (patient, name, date = nil)
      filters = { concept_id: concept(name), person_id: patient.person }
      filters.merge({ obs_datetime: date_range(date) }) if date
      Observation.where(filters).order(obs_datetime: :desc)
    end

    private

    def date_range (date)
      start_date, end_date = TimeUtils.day_bounds(date)
      start_date..end_date
    end
  end
end