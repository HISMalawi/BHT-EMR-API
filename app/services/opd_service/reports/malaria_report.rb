class OPDService::Reports::MalariaReport

  def find_report(start_date:, end_date:, **_extra_kwargs)
    @start_date = start_date
    @end_date = end_date
    malaria_report()
  end

  def malaria_report()
    confirm_ids           = get_confirm_malaria_data()
    combine_confirm_ids   = get_ids(confirm_ids)
    confirm_pregnant_ids  = get_pregnant_malaria_data(combine_confirm_ids )
    presume_ids           = get_presume_malaria_data(combine_confirm_ids)
    combine_presume_ids   = get_ids(presume_ids)
    presume_pregnant_ids  = get_pregnant_malaria_data(combine_presume_ids)

    confirm_LA_ids        = get_confirm_LA_data(combine_confirm_ids,'%Lumefantrine%')
    presume_LA_ids        = get_confirm_LA_data(combine_presume_ids,'%Lumefantrine%')
    confirm_ASAQ_ids      = get_confirm_LA_data(combine_confirm_ids,'%Artesunate%')
    presume_ASAQ_ids      = get_confirm_LA_data(combine_presume_ids,'%Artesunate%')

    all_LA_drugs          = get_drugs('LA(Lumefantrine + arthemether)')
    all_ASAQ_drugs        = get_drugs('Artesunate and amodiaquin')

    {
      confirm_ids: confirm_ids,
      presume_ids: presume_ids,
      confirm_pregnant_ids: confirm_pregnant_ids,
      presume_pregnant_ids: presume_pregnant_ids,
      confirm_LA_ids: confirm_LA_ids,
      presume_LA_ids: presume_LA_ids,
      confirm_ASAQ_ids: confirm_ASAQ_ids,
      presume_ASAQ_ids: presume_ASAQ_ids,
      all_LA_drugs: all_LA_drugs,
      all_ASAQ_drugs: all_ASAQ_drugs
    }
  end

  def get_pregnant_malaria_data(person_ids)
    Observation.where('obs_datetime BETWEEN ? AND ? AND c.name = ? AND obs.person_id IN(?) AND c.voided = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    'Patient pregnant',person_ids,0).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
    INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck("malaria_age_group(p.birthdate,'#{@end_date.to_date}') as age_group",:person_id).group_by(&:shift);
  end

  def get_presume_malaria_data(combine_confirm_ids)
    Observation.where('obs_datetime BETWEEN ? AND ? AND c.name = ? AND c.voided = ? AND p.person_id NOT IN(?)',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),'Malaria',0,combine_confirm_ids).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.value_coded
    INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck("malaria_age_group(p.birthdate,'#{@end_date.to_date}') as age_group",:person_id).group_by(&:shift);
  end

  def get_confirm_malaria_data()
    Observation.where('obs_datetime BETWEEN ? AND ? AND c.name IN(?) AND c.voided = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
    ['MRDT','Malaria Species','Malaria film'],0).\
    joins('INNER JOIN concept_name c ON c.concept_id = obs.concept_id
    INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck("malaria_age_group(p.birthdate,'#{@end_date.to_date}') as age_group",:person_id,:name).group_by(&:shift);
  end

  def get_confirm_LA_data(person_ids,drug_name)
    Observation.where("obs_datetime BETWEEN ? AND ? AND obs.person_id IN(?) AND o.instructions like ?
    ",@start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),person_ids,drug_name).\
    joins('INNER JOIN orders o ON o.order_id = obs.order_id
    INNER JOIN person p ON p.person_id = obs.person_id').\
    pluck("malaria_age_group(p.birthdate,'#{@end_date.to_date}') as age_group",:person_id).group_by(&:shift);
  end

  def get_drugs(concept_name)
    Order.where('orders.date_created BETWEEN ? AND ? AND c.name = ?',
    @start_date.to_date.strftime('%Y-%m-%d 00:00:00'),@end_date.to_date.strftime('%Y-%m-%d 23:59:59'),concept_name).\
    joins('INNER JOIN drug_order do ON do.order_id = orders.order_id
    INNER JOIN concept_name c ON c.concept_id = orders.concept_id').\
    pluck(:instructions,:patient_id,:quantity)
  end

  def get_ids(data)
    ids = []
    data.select { |element| ids = ids + data[element].flatten.group_by(&:class).values_at(String, Fixnum)[1]}
    return ids
  end
end