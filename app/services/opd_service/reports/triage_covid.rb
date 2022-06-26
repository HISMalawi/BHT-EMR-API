class OPDService::Reports::TriageCovid

  def find_report(start_date:, end_date:, **_extra_kwargs)
    @start_date = start_date
    @end_date = end_date
    triage_covid()
  end

  def triage_covid()
    value_text =['No other symptom','Cough','Difficulty breathing','Loss of taste or smell','Fatigue','Shortness of breath','Diarrhea','Vomiting','Generalised body Pains','Sore throat']
    Observation.where('obs_datetime BETWEEN ? AND ? AND obs.person_id IN (?) AND obs.value_text IN (?)',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),get_encounters(),value_text).\
    pluck('obs.value_text',:person_id).group_by(&:shift);
  end

  def get_encounters()
    data = Observation.where('obs_datetime BETWEEN ? AND ? AND c.name IN(?) AND c.voided = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    'History of COVID-19 contact',0).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id').\
    pluck(:person_id);
  end
end