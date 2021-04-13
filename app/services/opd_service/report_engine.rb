
require 'set'

module OPDService
  class ReportEngine
    include ModelUtils

    REPORTS = {
      'LA_PRESCRIPTIONS' => OPDService::Reports::LaPrescriptions
    }

    def initialize
    end

    def find_report(type:, **kwargs)
      report_engine(type).find_report(**kwargs)
    end

    # Retrieves the next encounter for bound patient
    def dashboard_stats(date)
      @date = date.to_date
      stats = {}
      stats[:top] = {
        registered_today: registered_today('New patient'),
        returning_today: registered_today('Revisiting'),
        referred_today: registered_today('Referral')
      }

      stats[:down] = {
        registered: monthly_registration('New patient'),
        returning: monthly_registration('Revisiting'),
        referred: monthly_registration('Referral')
      }

      return stats
    end

    def with_nids
      type = PatientIdentifierType.find_by_name 'Malawi National ID'

      data = Person.where('identifier_type = ?', type.id).\
        joins('INNER JOIN patient_identifier i ON i.patient_id = person.person_id
        RIGHT JOIN person_address a ON a.person_id = person.person_id
        RIGHT JOIN person_name n ON n.person_id = person.person_id').\
        select('person.*, a.state_province district, i.identifier nid,
        a.township_division ta, a.city_village village,
        n.given_name, n.family_name').order('n.date_created DESC')

      stats = []
      (data || []).each do |record|
        person = Person.find record['person_id']
        stats << {
          given_name: record['given_name'],
          family_name: record['family_name'],
          visit_type: record['visit_type'],
          birthdate: record['birthdate'],
          gender: record['gender'],
          nid:  record['nid']
        }
      end

      return stats
    end

    def diagnosis_by_address(start_date, end_date)
      type = EncounterType.find_by_name 'Outpatient diagnosis'

      data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND value_coded IS NOT NULL
        AND concept_id IN(6543, 6542)',
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id).\
        joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
        INNER JOIN person p ON p.person_id = encounter.patient_id
        RIGHT JOIN person_address a ON a.person_id = encounter.patient_id').\
        select('encounter.encounter_type, obs.value_coded, p.*,
        a.state_province district, a.township_division ta, a.city_village village')

      stats = {}

      (data || []).each do |record|
        concept = ConceptName.find_by_concept_id record['value_coded']
        district  = record['district']
        ta  = record['ta']
        village = record['village']

        address = "#{district}, #{ta}, #{village}"
        if stats[concept.name].blank?
          stats[concept.name] = {}
          stats[concept.name][address] = 0
        elsif stats[concept.name][address].blank?
          stats[concept.name][address] = 0
        end

        stats[concept.name][address] += 1
      end

      return stats
    end

    def registration(start_date, end_date)
      type = EncounterType.find_by_name 'PATIENT REGISTRATION'
       visit_type = ConceptName.find_by_name 'Type of visit'

      data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND value_coded IS NOT NULL
        AND obs.concept_id = ?', start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id, visit_type.concept_id).\
        joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
        INNER JOIN person p ON p.person_id = encounter.patient_id
        INNER JOIN concept_name c ON c.concept_id = obs.value_coded
        LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0').\
        select('encounter.encounter_type, n.family_name, n.given_name,
        obs.value_coded, obs.obs_datetime, p.*, c.name visit_type').\
        order('n.date_created DESC').group('n.person_id, encounter.encounter_id')

      stats = []
      (data || []).each do |record|
        stats << {
          given_name: record['given_name'],
          family_name: record['family_name'],
          visit_type: record['visit_type'],
          birthdate: record['birthdate'],
          gender: record['gender'],
          date: record['obs_datetime'].to_date
        }
      end

      return stats
    end

    def diagnosis(start_date, end_date)
      type = EncounterType.find_by_name 'Outpatient diagnosis'
      data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND value_coded IS NOT NULL
        AND concept_id IN(6543, 6542)',
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id).\
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

    def drugs_given_without_prescription(start_date, end_date)
      type = EncounterType.find_by_name 'DRUGS GIVEN'
       visit_type = ConceptName.find_by_name 'Given drugs'

      data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND obs.concept_id = ?',
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id, visit_type.concept_id).\
        joins('INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
        INNER JOIN person p ON p.person_id = encounter.patient_id
        INNER JOIN drug d ON d.drug_id = obs.value_drug
        LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0').\
        select('encounter.patient_id, obs.value_numeric,
        d.drug_id, obs.obs_datetime,n.given_name, n.family_name, p.*, d.name drug_name').\
        order('n.date_created DESC').group('n.person_id, encounter.encounter_id')

      stats = []
      (data || []).each do |record|
        stats << {
          given_name: record['given_name'],
          family_name: record['family_name'],
          drug_name: record['drug_name'],
          drug_id: record['drug_id'],
          gender: record['gender'],
          date: record['obs_datetime'].to_date,
          patient_id: record['patient_id'],
          quantity: record['value_numeric']
        }
      end

      return stats
    end

    def drugs_given_with_prescription(start_date, end_date)
      type = EncounterType.find_by_name 'TREATMENT'

      data = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ? AND i.quantity > 0',
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),type.id).\
        joins('INNER JOIN orders o ON o.encounter_id = encounter.encounter_id
        INNER JOIN person p ON p.person_id = encounter.patient_id
        INNER JOIN drug_order i ON i.order_id = o.order_id
        INNER JOIN drug d ON d.drug_id = i.drug_inventory_id
        LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0').\
        select('encounter.patient_id person_id, i.quantity,
        given_name, family_name, d.drug_id, o.start_date, p.*, d.name drug_name').\
        order('n.date_created DESC').group('n.person_id, o.order_id')

      stats = []
      (data || []).each do |record|
        stats << {
          given_name: record['given_name'],
          family_name: record['family_name'],
          drug_name: record['drug_name'],
          drug_id: record['drug_id'],
          gender: record['gender'],
          date: record['start_date'].to_date,
          patient_id: record['person_id'],
          quantity: record['quantity']
        }
      end

      return stats
    end

    private

    def report_engine(type)
      REPORTS[type.upcase].new
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

    def registered_today(visit_type)
      type = EncounterType.find_by_name 'Patient registration'
      concept = ConceptName.find_by_name 'Type of visit'
      value_coded = ConceptName.find_by_name visit_type

      encounter_ids = Encounter.where('encounter_datetime BETWEEN ? AND ?
        AND encounter_type = ?', *TimeUtils.day_bounds(@date), type.id).map(&:encounter_id)

      return Observation.where('encounter_id IN(?) AND concept_id = ? AND value_coded = ?',
        encounter_ids, concept.concept_id, value_coded.concept_id).group(:person_id).length
    end

    def monthly_registration(visit_type)
      start_date = (@date - 12.month)
      dates = []

      start_date = start_date.beginning_of_month
      end_date  = start_date.end_of_month
      dates << [start_date, end_date]

      1.upto(11) do |m|
        sdate = start_date + m.month
        edate = sdate.end_of_month
        dates << [sdate, edate]
      end

      type = EncounterType.find_by_name 'Patient registration'
      concept = ConceptName.find_by_name 'Type of visit'
      value_coded = ConceptName.find_by_name visit_type

      months = {}

      (dates || []).each_with_index do |(date1, date2), i|
        count = Encounter.where('encounter_datetime BETWEEN ? AND ?
          AND encounter_type = ? AND concept_id = ?
          AND value_coded = ?', date1.strftime('%Y-%m-%d 00:00:00'),
          date2.strftime('%Y-%m-%d 23:59:59'), type.id,
          concept.concept_id, value_coded.concept_id).\
          joins('INNER JOIN obs USING(encounter_id)').\
          select('count(*) AS total')

        months[(i+1)]= {
          start_date: date1, end_date: date2,
          count: count[0]['total'].to_i
        }
      end

      months
    end

  end
end
