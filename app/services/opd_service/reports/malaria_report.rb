class OPDService::Reports::MalariaReport

  def find_report(start_date:, end_date:, **_extra_kwargs)
    @start_date = start_date
    @end_date = end_date
    malaria_report()
  end

  def registration()
    type = EncounterType.find_by_name 'PATIENT REGISTRATION'
    visit_type = ConceptName.find_by_name 'Type of visit'

    data = Encounter.where('encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ? AND value_coded IS NOT NULL
      AND obs.concept_id = ?', @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
      @end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id, visit_type.concept_id).\
      joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
      INNER JOIN concept_name c ON c.concept_id = obs.value_coded
      INNER JOIN person p ON p.person_id = obs.person_id').\
      group('obs.person_id').pluck("malaria_report('','','','','',c.name,p.birthdate,'#{@end_date.to_date}')
      as malaria_data",'obs.person_id').group_by(&:shift);
  end

  def malaria_report()
    @malaria_data = Observation.where("obs_datetime BETWEEN ? AND ?  AND c.voided = ? AND c.name IN (?) AND
      malaria_report(obs.order_id,obs.value_text,obs.value_coded,obs.person_id,DATE(obs_datetime),c.name,p.birthdate,'#{@end_date.to_date}') IS NOT NULL",
      @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
      0,['Amount dispensed','MRDT','Malaria film','Malaria Species','Primary diagnosis']).\
      joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
      INNER JOIN person p ON p.person_id = obs.person_id').\
      pluck("malaria_report(obs.order_id,obs.value_text,obs.value_coded,obs.person_id,DATE(obs_datetime),c.name,p.birthdate,'#{@end_date.to_date}')
      as malaria_data",:person_id).group_by(&:shift);

    build_malaria_hash
  end

  def build_malaria_hash
    confrim_non_pregnant_5more = get_ids('> 5yrs','confrim_non_pregnant','')
    confrim_non_pregnant_5less = get_ids('< 5yrs','confrim_non_pregnant','')
    presume_non_pregnant_5more = get_ids('> 5yrs','presume_non_pregnant','')
    presume_non_pregnant_5less = get_ids('< 5yrs','presume_non_pregnant','')
    confirm_pregnant_5more     = get_ids('> 5yrs','confirm_pregnant','')
    confirm_pregnant_5less     = get_ids('< 5yrs','confirm_pregnant','')
    presume_pregnant_5more     = get_ids('> 5yrs','presume_pregnant','')
    presume_pregnant_5less     = get_ids('< 5yrs','presume_pregnant','')
    total_OPD_malaria_cases_5more = confrim_non_pregnant_5more +presume_non_pregnant_5more +confirm_pregnant_5more +presume_pregnant_5more
    total_OPD_malaria_cases_5less = confrim_non_pregnant_5less +presume_non_pregnant_5less +confirm_pregnant_5less +presume_pregnant_5less

    suspected_malaria_mRDT_less_5yrs       = get_ids('< 5yrs','negative_MRDT','')
    suspected_malaria_mRDT_more_5yrs       = get_ids('> 5yrs','negative_MRDT','')
    suspected_malaria_microscopy_less_5yrs = get_ids('< 5yrs','negative_Malaria film','')
    suspected_malaria_microscopy_more_5yrs = get_ids('> 5yrs','negative_Malaria film','')
    total_suspected_malaria_5more = suspected_malaria_mRDT_more_5yrs +suspected_malaria_microscopy_more_5yrs +presume_non_pregnant_5more +presume_pregnant_5more
    total_suspected_malaria_5less = suspected_malaria_mRDT_less_5yrs +suspected_malaria_microscopy_less_5yrs +presume_non_pregnant_5less +presume_pregnant_5less

    {
      confrim_non_pregnant_more_5yrs: confrim_non_pregnant_5more,
      confrim_non_pregnant_less_5yrs: confrim_non_pregnant_5less,
      presume_non_pregnant_more_5yrs: presume_non_pregnant_5more,
      presume_non_pregnant_less_5yrs: presume_non_pregnant_5less,
      confirm_pregnant_less_5yrs: confirm_pregnant_5less,
      confirm_pregnant_more_5yrs: confirm_pregnant_5more,
      presume_pregnant_less_5yrs: presume_pregnant_5less,
      presume_pregnant_more_5yrs: presume_pregnant_5more,
      total_OPD_malaria_cases_more_5yrs: total_OPD_malaria_cases_5more,
      total_OPD_malaria_cases_less_5yrs: total_OPD_malaria_cases_5less,
      total_OPD_attendance: registration(),
      confirmed_malaria_treatment_failure_less_5yrs: get_ids('< 5yrs','confirmed_malaria_treatment_failure',''),
      confirmed_malaria_treatment_failure_more_5yrs: get_ids('> 5yrs','confirmed_malaria_treatment_failure',''),
      presumed_malaria_LA_less_5yrs: get_ids('< 5yrs','presume','Lumefantrine'),
      presumed_malaria_LA_more_5yrs: get_ids('> 5yrs','presume','Lumefantrine'),
      presumed_malaria_ASAQ_less_5yrs: get_ids('< 5yrs','presume','Artesunate'),
      presumed_malaria_ASAQ_more_5yrs: get_ids('> 5yrs','presume','Artesunate'),
      confirmed_malaria_LA_less_5yrs: get_ids('< 5yrs','confrim','Lumefantrine'),
      confirmed_malaria_LA_more_5yrs: get_ids('> 5yrs','confrim','Lumefantrine'),
      confirmed_malaria_ASAQ_less_5yrs: get_ids('< 5yrs','confrim','Artesunate'),
      confirmed_malaria_ASAQ_more_5yrs: get_ids('> 5yrs','confrim','Artesunate'),
      suspected_malaria_mRDT_less_5yrs: suspected_malaria_mRDT_less_5yrs,
      suspected_malaria_mRDT_more_5yrs: suspected_malaria_mRDT_more_5yrs,
      positive_malaria_mRDT_less_5yrs: get_ids('< 5yrs','positive_MRDT',''),
      positive_malaria_mRDT_more_5yrs: get_ids('> 5yrs','positive_MRDT',''),
      suspected_malaria_microscopy_less_5yrs: suspected_malaria_microscopy_less_5yrs,
      suspected_malaria_microscopy_more_5yrs: suspected_malaria_microscopy_more_5yrs,
      positive_malaria_microscopy_less_5yrs: get_ids('< 5yrs','positive_Malaria film',''),
      positive_malaria_microscopy_more_5yrs: get_ids('> 5yrs','positive_Malaria film',''),
      total_suspected_malaria_cases_less_5yrs: total_suspected_malaria_5less,
      total_suspected_malaria_cases_more_5yrs: total_suspected_malaria_5more,
      LA_1X6: get_ids('','','Lumefantrine + Arthemether 1 x 6'),
      LA_2X6: get_ids('','','Lumefantrine + Arthemether 2 x 6'),
      LA_3X6: get_ids('','','Lumefantrine + Arthemether 3 x 6'),
      LA_4X6: get_ids('','','Lumefantrine + Arthemether 4 x 6'),
      sp: get_ids('','','SP'),
      ASAQ_25mg: get_ids('','','ASAQ 25mg/67.5mg (3 tablets)'),
      ASAQ_50mg: get_ids('','','ASAQ 50mg/135mg (3 tablets)'),
      ASAQ_100mg_3tabs: get_ids('','','ASAQ 100mg/270mg (3 tablets)'),
      ASAQ_100mg_6tabs: get_ids('','','ASAQ 100mg/270mg (6 tablets)')
    }
  end

  def get_ids(age_range,condition_name,drug_name)
    array_id = []
    @malaria_data.select { |element|
      array_id << @malaria_data[element] if element.match?(age_range) && element.match?(condition_name) && drug_name == ""
      array_id << @malaria_data[element] if element.match?(age_range) && element.match?(condition_name) && element.match?(drug_name) && drug_name != ""
      array_id << @malaria_data[element] if age_range == ""  && element.match?(drug_name)
    }
    return array_id.flatten
  end
end