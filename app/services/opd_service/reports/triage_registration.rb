class OPDService::Reports::TriageRegistration

  def find_report(start_date:, end_date:, **_extra_kwargs)
    @start_date = start_date
    @end_date = end_date
    triage_registration()
  end

  def triage_registration()
    data = Observation.where('obs_datetime BETWEEN ? AND ? AND c.name IN(?) AND c.voided = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    'History of COVID-19 contact',0).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
    INNER JOIN person p ON p.person_id = obs.person_id').\
    group(:person_id).pluck(:gender,:person_id).group_by(&:shift);
  end

end