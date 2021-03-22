class Api::V1::FastTrackController < ApplicationController

  def assessment
    patient_id  = params[:patient_id]
    date        = params[:date].to_date

    patient_assessment = {
      adult: nil, on_art_for_12_plus_months: nil,
      on_first_line_regimen: nil, good_adherence: nil,
      last_vl_less_than_1000: nil, pregnant_breastfeeding: 'N/A',
      any_side_effects: nil, any_signs_of_tb: nil,
      started_ipt_less_than_12_months_ago: nil
    }

    person = Person.find patient_id
    person_age = age person, date

    patient_assessment[:adult]                                = (person_age >= 1)
    patient_assessment[:pregnant_breastfeeding]               = pregnant_breastfeeding? patient_id, date
    patient_assessment[:on_art_for_12_plus_months]            = on_art_for_12_plus_months patient_id, date
    patient_assessment[:on_first_line_regimen]                = on_first_line_regimen patient_id, date
    patient_assessment[:good_adherence]                       = good_adherence? patient_id, date
    patient_assessment[:any_signs_of_tb]                      = any_signs_of_tb? patient_id, date
    patient_assessment[:started_ipt_less_than_12_months_ago]  = started_ipt_less_than_12_months_ago? patient_id, date
    patient_assessment[:any_side_effects]                     = any_side_effects? patient_id, date
    patient_assessment[:needs_bp_diabetes_treatment]          = nil

    render json: patient_assessment
  end

  def on_fast_track
    patient_id  = params[:person_id]
    date        = params[:date]&.to_date || Date.today

    previous_ft = Observation.where("person_id = ? AND obs_datetime <= ?
      AND concept_id = ?", patient_id, date.strftime('%Y-%m-%d 23:59:59'),
      ConceptName.find_by_name('FAST').concept_id).order('obs_datetime DESC').first

    ans = false if previous_ft.blank?
    unless previous_ft.blank?
      yes = ConceptName.find_by_name('Yes').concept_id
      ans = previous_ft.value_coded.to_i == yes ? true : false
    end

    render json: {'continue FT': ans}
  end

  def cancel
    patient_id  = params[:person_id]
    date        = params[:date].to_date

    time = Time.now().strftime('%H:%M:%S')
    obs_datetime = date.strftime('%Y-%m-%d')

    encounter_id = Observation.where("person_id = ? AND obs_datetime <= ?
      AND concept_id = ?", patient_id, date.strftime('%Y-%m-%d 23:59:59'),
      ConceptName.find_by_name('FAST').concept_id).order('obs_datetime DESC').first.encounter_id

    obs = Observation.create(person_id: patient_id,
      obs_datetime: "#{date} #{time}",
      location_id: Location.current.id,
      concept_id: ConceptName.find_by_name('FAST').concept_id,
      value_coded: ConceptName.find_by_name('No').concept_id,
      encounter_id: encounter_id)

    render json: obs
  end

  private

  def age(person, today)
    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + \
     ((today.month - person.birthdate.month) + \
      ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=person.birthdate
    estimate=person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  \
      && today.month < birth_date.month && \
        person.date_created.year == today.year) ? 1 : 0

    patient_age
  end

  def pregnant_breastfeeding?(patient_id, passed_date)
    patient_pregnant_concept    = concept "IS PATIENT PREGNANT?"
    patient_breastfeed_concept  = concept "IS PATIENT BREAST FEEDING?"
    yes_concept                 = concept "Yes"

    latest_clinical_consultation = Encounter.where('encounter_type = ?
      AND patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)',
        EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,
        patient_id, passed_date.strftime('%Y-%m-%d 00:00:00'),
        passed_date.strftime('%Y-%m-%d 23:59:59'))\
        .order('encounter_datetime DESC').first

    return false if latest_clinical_consultation.blank?

    pregnant_breastfeeding = Observation.where('person_id = ?
      AND (obs_datetime BETWEEN ? AND ?)  AND concept_id IN(?)
      AND encounter_id = ?', patient_id,
      passed_date.strftime('%Y-%m-%d 00:00:00'),
      passed_date.strftime('%Y-%m-%d 23:59:59'),
        [patient_pregnant_concept.concept_id,
        patient_breastfeed_concept.concept_id],
        latest_clinical_consultation.encounter_id).order('obs_datetime DESC')

    yes_no = false

    (pregnant_breastfeeding || []).each do |ob|
      yes_no = true if ob.value_coded = yes_concept.concept_id
    end

    yes_no
  end

  def on_art_for_12_plus_months(patient_id, passed_date)
    query = ActiveRecord::Base.connection.select_one <<EOF
    SELECT date_antiretrovirals_started(#{patient_id}, DATE("#{passed_date.to_date}")) AS start_date;
EOF

    begin
      (date.to_date - query['start_date'].to_date).to_i >= 1
    rescue
      false
    end
  end

  def on_first_line_regimen(patient_id, passed_date)
    query = ActiveRecord::Base.connection.select_one <<EOF
    SELECT patient_current_regimen(#{patient_id}, DATE("#{passed_date.to_date}")) AS regimen;
EOF

    begin
      regimen_num = query['regimen'].gsub(/[^\d]/, '')
      return false if regimen_num.blank?
      return regimen_num <= 6
    rescue
      false
    end
  end

  def good_adherence?(patient_id, passed_date)
    art_adherence_concept = concept 'What was the patients adherence for this drug order'

    latest_art_adherence = Encounter.where('encounter_type = ?
      AND patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)',
      EncounterType.find_by_name("ART ADHERENCE").id,
      patient_id,passed_date.strftime('%Y-%m-%d 00:00:00'),
      passed_date.strftime('%Y-%m-%d 23:59:59'))  \
      .order('encounter_datetime DESC').first

    return false if latest_art_adherence.blank?

    art_adherence_obs = Observation.where('person_id = ?
      AND (obs_datetime BETWEEN ? AND ?) AND concept_id IN(?)
      AND encounter_id = ?', patient_id,
      passed_date.strftime('%Y-%m-%d 00:00:00'),
      passed_date.strftime('%Y-%m-%d 23:59:59'),
      [art_adherence_concept.concept_id],
      latest_art_adherence.encounter_id).order('obs_datetime DESC')

    adherence_good = true;

    (art_adherence_obs || []).each do |ad|
      rate = ad.value_text.to_f unless ad.value_text.blank?
      rate = ad.value_numeric.to_f unless ad.value_numeric.blank?
      rate = 0 if rate.blank?

      next if rate >= 95 && rate <= 105

      adherence_good = false
    end

    adherence_good
  end

  def any_signs_of_tb?(patient_id, passed_date)
    concept_names = ['Weight loss / Failure to thrive / malnutrition',
      'Night sweats','Fever','Cough of any duration']
    yes_concept           = concept 'Yes'

    concept_ids = []
    concept_names.each do |name|
      concept_ids << concept(name).concept_id
    end

    tb_signs_obs = Observation.where('person_id = ?
      AND (obs_datetime BETWEEN ? AND ?) AND concept_id IN(?)',
      patient_id, passed_date.strftime('%Y-%m-%d 00:00:00'),
      passed_date.strftime('%Y-%m-%d 23:59:59'),
      concept_ids).order('obs_datetime DESC')

    sign_available = false

    (tb_signs_obs || []).each do |ob|
      sign_available = true if ob.value_coded == yes_concept.concept_id
    end

    sign_available
  end

  def started_ipt_less_than_12_months_ago?(patient_id, passed_date)
    drugs = Drug.where('combination = 0 AND name LIKE ?', '%Isoniazid%')
    drug_ids = drugs.map{|d| d.id}

    order = DrugOrder.where('drug_order.drug_inventory_id IN(?)
      AND o.patient_id = ? AND start_date <= ?', \
      drug_ids, patient_id, passed_date.strftime('%Y-%m-%d 23:59:59')). \
      joins("INNER JOIN orders o USING(order_id)") \
      .order('o.start_date ASC') \
      .select('o.*')

   return false if order.blank?

   start_date = order.first.start_date.to_date
   (passed_date - start_date).to_i < 1
  end

  def any_side_effects?(patient_id, passed_date)
    concept_names = ['Gynaecomastia','Anemia','Hepatitis','Jaundice',
      'Yellow eye','Psychosis','Skin rash','Peripheral neuropathy','Dizziness',
      'Lipodystrophy','Nightmares','Renal failure','Blurry Vision',
      'Kidney Failure']

    concept_ids = []
    yes_concept = concept 'Yes'

    concept_names.each do |name|
      concept_ids << concept(name).concept_id
    end

    side_effects = Observation  \
                  .where('person_id = ?
        AND (obs_datetime BETWEEN ? AND ?) AND concept_id IN(?)', patient_id,
          passed_date.strftime('%Y-%m-%d 00:00:00'),
            passed_date.strftime('%Y-%m-%d 23:59:59'), concept_ids)  \
                   .order('obs_datetime DESC')

    side_effects_avilable = false

    (side_effects || []).each do |ob|
      side_effects_avilable = true if ob.value_coded == yes_concept.concept_id
    end

    side_effects_avilable
  end

  def concept(concept_name)
    ConceptName.find_by_name concept_name
  end
end
