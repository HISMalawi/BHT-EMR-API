class OPDService::Reports::Diagnosis

  def find_report(start_date:, end_date:, **_extra_kwargs)
    diagnosis(start_date, end_date)
  end

  def diagnosis(start_date, end_date)
    type = EncounterType.find_by_name 'Outpatient diagnosis'
    data = Encounter.where('encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ?
      AND obs.concept_id IN(6543, 6542)',
      start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
      end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id).\
      joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
      INNER JOIN person p ON p.person_id = encounter.patient_id
      LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0
      LEFT JOIN person_attribute z ON z.person_id = encounter.patient_id AND z.person_attribute_type_id = 12
      RIGHT JOIN person_address a ON a.person_id = encounter.patient_id
      INNER JOIN concept_name c ON c.concept_id = obs.value_coded
      ').\
      group('obs.person_id,obs.value_coded,DATE(obs.obs_datetime)').\
      select("encounter.encounter_type,n.given_name, n.family_name, n.person_id, obs.value_coded, p.gender,
      a.state_province district, a.township_division ta, a.city_village village, z.value,
      cohort_disaggregated_age_group(p.birthdate,'#{end_date.to_date}') as age_group,c.name")

      create_diagnosis_hash(data)
  end

  def create_diagnosis_hash(data)
    records = {}
    (data || []).each do |record|
      age_group = record['age_group'].blank? ? "Unknown" : record['age_group']
      gender = record['gender'].match(/f/i) ? "F" : (record['gender'].match(/m/i) ? "M" : "Unknown")
      patient_id = record['person_id']
      diagnosis = record['name']

      if records[diagnosis].blank?
        records[diagnosis] = {}
      end

      if records[diagnosis][gender].blank?
        records[diagnosis][gender] = {}
      end

      if records[diagnosis][gender][age_group].blank?
        records[diagnosis][gender][age_group] = []
      end

      records[diagnosis][gender][age_group] << patient_id

    end

    records
  end
end