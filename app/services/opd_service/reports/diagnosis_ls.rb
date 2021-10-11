class OPDService::Reports::Diagnosis_Ls
  def find_report(start_date:, end_date:, **_extra_kwargs)
    diagnosis_ls(start_date, end_date)
  end

  private
  def diagnosis_ls(start_date, end_date)
    type = EncounterType.find_by_name 'Outpatient diagnosis'
    data = Encounter.where('encounter_datetime BETWEEN ? AND ?
    AND encounter_type = ? AND value_coded IS NOT NULL
    AND concept_id IN(6543, 6542)',
    start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
    end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id).\
    joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id').\
    select('encounter.encounter_type, obs.value_coded').group('obs.value_coded')

    ls = []
    stats = {}
    (data || []).each do |record|

      concept = ConceptName.find_by_concept_id record['value_coded']
      if (concept != nil)
      ls.push(concept.name)
      end
    end

    return ls
  end
end