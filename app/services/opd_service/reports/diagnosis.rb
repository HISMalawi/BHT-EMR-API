require 'set'

class OPDService::Reports::Diagnosis
  include ModelUtils

  def find_report(start_date:, end_date:,diagnosis_name:, **_extra_kwargs)
    diagnosis(start_date, end_date, diagnosis_name)
  end

  def diagnosis(start_date, end_date, diagnosis_name)
    conceptt = ConceptName.find_by_name(diagnosis_name).concept_id
    type = EncounterType.find_by_name 'Outpatient diagnosis'
    data = Encounter.where('encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ? AND value_coded = ?
      AND concept_id IN(6543, 6542)',
      start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
      end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id,conceptt).\
      joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
      INNER JOIN person p ON p.person_id = encounter.patient_id
      LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0
      LEFT JOIN person_attribute z ON z.person_id = encounter.patient_id AND z.person_attribute_type_id = 12
      RIGHT JOIN person_address a ON a.person_id = encounter.patient_id').\
      select('encounter.encounter_type,n.given_name, n.family_name, n.person_id, obs.value_coded, p.*,
      a.state_province district, a.township_division ta, a.city_village village, z.value')

    stats = {}
    (data || []).each do |record|
      age_group = get_age_group(record['birthdate'], end_date)
      phone_number = record['value']
      gender = record['gender']
      given_name = record['given_name']
      family_name = record['family_name']
      district  = record['district']
      ta  = record['ta']
      village = record['village']
      address = "#{district}; #{ta}; #{village}"
      patient_info = "|#{given_name},#{record['person_id']},#{family_name},#{gender},#{phone_number},#{address}";
      concept = ConceptName.find_by_concept_id record['value_coded']

      next if gender.blank?

      if stats[concept.name].blank?
        stats[concept.name] = {
          female_less_than_six_months: 0,
          patientD_F_LessSixMonths: '',
          male_less_than_six_months: 0,
          patientD_M_LessSixMonths: '',
          female_six_months_to_less_than_five_yrs: 0,
          patientD_F_LessFiveYrs: '',
          male_six_months_to_less_than_five_yrs: 0,
          patientD_M_LessFiveYrs: '',
          female_five_yrs_to_fourteen_years: 0,
          patientD_F_5yrsTo14yrs: '',
          male_five_yrs_to_fourteen_years: 0,
          patientD_M_5yrsTo14yrs: '',
          female_over_fourteen_years: 0,
          patientD_F_Over14Yrs: '',
          male_over_fourteen_years: 0,
          patientD_M_Over14Yrs: '',
          female_unknowns: 0,
          patientD_F_unknowns: '',
          male_unknowns: 0,
          patientD_M_unknowns: '',
        }
      end

      if age_group == 'months < 6' && gender == 'F'
        stats[concept.name][:female_less_than_six_months] += 1
        stats[concept.name][:patientD_F_LessSixMonths] = "#{stats[concept.name][:patientD_F_LessSixMonths]} #{patient_info}"
      elsif age_group == 'months < 6' && gender == 'M'
        stats[concept.name][:male_less_than_six_months] += 1
        stats[concept.name][:patientD_M_LessSixMonths] = "#{stats[concept.name][:patientD_M_LessSixMonths]} #{patient_info}"
      elsif age_group == '6 months < 5 yrs' && gender == 'F'
        stats[concept.name][:female_six_months_to_less_than_five_yrs] += 1
        stats[concept.name][:patientD_F_LessFiveYrs] = "#{stats[concept.name][:patientD_F_LessFiveYrs]} #{patient_info}"
      elsif age_group == '6 months < 5 yrs' && gender == 'M'
        stats[concept.name][:male_six_months_to_less_than_five_yrs] += 1
        stats[concept.name][:patientD_M_LessFiveYrs] = "#{stats[concept.name][:patientD_M_LessFiveYrs]} #{patient_info}"
      elsif age_group == '5 yrs to 14 yrs' && gender == 'F'
        stats[concept.name][:female_five_yrs_to_fourteen_years] += 1
        stats[concept.name][:patientD_F_5yrsTo14yrs] = "#{stats[concept.name][:patientD_F_5yrsTo14yrs]} #{patient_info}"
      elsif age_group == '5 yrs to 14 yrs' && gender == 'M'
        stats[concept.name][:male_five_yrs_to_fourteen_years] += 1
        stats[concept.name][:patientD_M_5yrsTo14yrs] = "#{stats[concept.name][:patientD_M_5yrsTo14yrs]} #{patient_info}"
      elsif age_group == '> 14 yrs' && gender == 'F'
        stats[concept.name][:female_over_fourteen_years] += 1
        stats[concept.name][:patientD_F_Over14Yrs] = "#{stats[concept.name][:patientD_F_Over14Yrs]} #{patient_info}"
      elsif age_group == '> 14 yrs' && gender == 'M'
        stats[concept.name][:male_over_fourteen_years] += 1
        stats[concept.name][:patientD_M_Over14Yrs] = "#{stats[concept.name][:patientD_M_Over14Yrs]} #{patient_info}"
      elsif age_group == 'Unknown' && gender == 'F'
        stats[concept.name][:female_unknowns] += 1
        stats[concept.name][:patientD_F_unknowns] = "#{stats[concept.name][:patientD_F_unknowns]} #{patient_info}"
      elsif age_group == 'Unknown' && gender == 'M'
        stats[concept.name][:male_unknowns] += 1
        stats[concept.name][:patientD_M_unknowns] = "#{stats[concept.name][:patientD_M_unknowns]} #{patient_info}"
      end

    end

    return stats
  end

  def get_age_group(birthdate, end_date)
    begin
      birthdate = birthdate.to_date
      end_date  = end_date.to_date
      months = age_in_months(birthdate, end_date)
    rescue
      months = 'Unknown'
    end

    if months == 'Unknown'
      return 'Unknown'
    elsif months < 6
      return '< 6 months'
    elsif months >= 6 && months < 56
      return '6 months < 5 yrs'
    elsif months >= 56 && months <= 168
      return '5 yrs to 14 yrs'
    elsif months > 168
      return '> 14 yrs'
    else
      return 'Unknown'
    end
  end

  def age_in_months(birthdate, today)
    begin
      years = (today.year - birthdate.year)
      months = (today.month - birthdate.month)
      return (years * 12) + months
    rescue
      return 'Unknown'
    end
  end
end