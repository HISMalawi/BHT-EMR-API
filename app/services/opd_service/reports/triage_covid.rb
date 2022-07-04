class OPDService::Reports::TriageCovid

  def find_report(start_date:, end_date:, **_extra_kwargs)
    @start_date = start_date
    @end_date = end_date
    triage_covid()
  end

  def triage_covid()
    value_text =['No other symptom','Cough','Difficulty breathing','Loss of taste or smell','Fatigue',
                  'Shortness of breath','Diarrhea','Vomiting','Generalised body Pains','Sore throat']

    data =Observation.where('obs_datetime BETWEEN ? AND ? AND obs.person_id IN (?) AND obs.value_text IN (?)
     AND triage_covid_report(DATE(obs_datetime),obs.person_id) is not null',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    get_ids(triage_registration.group_by(&:shift)),value_text).\
    joins('INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck('obs.value_text',:gender,:person_id)

    group_by_gender((get_history_covid + data + triage_registration).group_by(&:shift))
  end

  def triage_registration()
    data = Observation.where('obs_datetime BETWEEN ? AND ? AND c.name IN(?) AND c.voided = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    'History of COVID-19 contact',0).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
      INNER JOIN person p ON p.person_id = obs.person_id').group(:person_id).\
    pluck("CASE name WHEN 'History of COVID-19 contact' THEN 'Total' END as name",:gender,:person_id);
  end

  def get_history_covid()
    Observation.where('obs_datetime BETWEEN ? AND ? AND c.name IN(?) AND c.voided = ? AND obs.value_text = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    'History of COVID-19 contact',0,'Yes').\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
      INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck(:name,:gender,:person_id);
  end

  def group_by_gender(data)
    obs = {}
    data.select { |element| obs[element] = data[element].group_by(&:shift)}
    return obs
  end

  def get_ids(data)
    ids = []
    data.select { |element| ids = ids + data[element].flatten.group_by(&:class).values_at(String, Fixnum)[1]}
    return ids
  end
end