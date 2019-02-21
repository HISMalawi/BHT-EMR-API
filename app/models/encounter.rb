class Encounter < VoidableRecord
  self.table_name = :encounter
  self.primary_key = :encounter_id

  # before_save :before_save
  # after_save :after_save
  after_void :after_void

  has_many :observations, dependent: :destroy
  has_many :drug_orders, through: :orders, foreign_key: 'order_id'
  has_many :orders, dependent: :destroy

  belongs_to :type, class_name: 'EncounterType', foreign_key: :encounter_type
  belongs_to :provider, class_name: 'Person', foreign_key: :provider_id
  belongs_to :patient
  belongs_to :location, optional: true
  belongs_to :program

  validates_presence_of :encounter_datetime

  # # TODO: this needs to account for current visit, which needs to account for
  # # possible retrospective entry
  # named_scope(:current,
  #             conditions: 'DATE(encounter.encounter_datetime) = CURRENT_DATE()')

  def as_json(options = {})
    super(options.merge(
      include: {
        type: {},
        patient: {},
        location: {},
        provider: {
          except: %i[
            password salt secret_question secret_answer
            authentication_token token_expiry_time
          ]
        },
        program: {},
        observations: {
          include: {
            concept: {
              include: {
                concept_names: {}
              }
            }
          }
        }
      }
    ))
  end

  # def before_save
  #   self.provider = User.current_user if provider.blank?
  #   # TODO, this needs to account for current visit, which needs to account for
  #   # possible retrospective entry
  #   self.encounter_datetime = Time.now if encounter_datetime.blank?
  # end

  # def after_save
  #   add_location_obs
  # end

  def after_void(reason)
    orders.each { |order| order.void(reason) }

    if encounter_type == EncounterType.find_by_name('ART ADHERENCE').id
      # Hack for ART ADHERENCE that blocks observation from voiding any attached
      # orders
      observations.each { |observation| observation.void(reason, skip_after_void: true) }
    else
      observations.each { |observation| observation.void(reason) }
    end
  end

  def encounter_type_name=(encounter_type_name)
    self.type = EncounterType.find_by_name(encounter_type_name)
    raise "#{encounter_type_name} not a valid encounter_type" if type.nil?
  end

  # def self.initial_encounter
  #   find_by_sql("SELECT * FROM encounter ORDER BY encounter_datetime LIMIT 1").first
  # end

  # def voided_observations
  #   voided_obs = Observation.find_by_sql("SELECT * FROM obs WHERE obs.encounter_id = #{self.encounter_id} AND obs.voided = 1")
  #   (!voided_obs.empty?) ? voided_obs : nil
  # end

  # def voided_orders
  #   voided_orders = Order.find_by_sql("SELECT * FROM orders WHERE orders.encounter_id = #{self.encounter_id} AND orders.voided = 1")
  #   (!voided_orders.empty?) ? voided_orders : nil
  # end

  def name
    self.type&.name || 'N/A'
  end

  # def to_s
  #   if name == 'REGISTRATION'
  #     "Patient was seen at the registration desk at #{encounter_datetime.strftime('%I:%M')}"
  #   elsif name == 'TREATMENT'
  #     o = orders.collect{|order| order.to_s}.join("\n")
  #     o = "No prescriptions have been made" if o.blank?
  #     o
  #   elsif name == 'VITALS'
  #     temp = observations.select {|obs| obs.concept.concept_names.map(&:name).include?("TEMPERATURE (C)") && "#{obs.answer_string}".upcase != 'UNKNOWN' }
  #     weight = observations.select {|obs| obs.concept.concept_names.map(&:name).include?("WEIGHT (KG)") || obs.concept.concept_names.map(&:name).include?("Weight (kg)") && "#{obs.answer_string}".upcase != '0.0' }
  #     height = observations.select {|obs| obs.concept.concept_names.map(&:name).include?("HEIGHT (CM)") || obs.concept.concept_names.map(&:name).include?("Height (cm)") && "#{obs.answer_string}".upcase != '0.0' }
  #     vitals = [weight_str = weight.first.answer_string + 'KG' rescue 'UNKNOWN WEIGHT',
  #               height_str = height.first.answer_string + 'CM' rescue 'UNKNOWN HEIGHT']
  #     temp_str = temp.first.answer_string + '°C' rescue nil
  #     vitals << temp_str if temp_str
  #     vitals.join(', ')
  #   else
  #     observations.collect{|observation| "<b>#{(observation.concept.concept_names.last.name) rescue ""}</b>: #{observation.answer_string}"}.join(", ")
  #   end
  # end

  # def self.count_by_type_for_date(date)
  #   # This query can be very time consuming, because of this we will not consider
  #   # that some of the encounters on the specific date may have been voided
  #   ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
  #   todays_encounters = Encounter.find(:all, include: "type", conditions: ["DATE(encounter_datetime) = ?",date])
  #   encounters_by_type = Hash.new(0)
  #   todays_encounters.each{|encounter|
  #     next if encounter.type.nil?
  #     encounters_by_type[encounter.type.name] += 1
  #   }
  #   encounters_by_type
  # end

  # def self.statistics(encounter_types, opts={})
  #   encounter_types = EncounterType.all(:conditions => ['name IN (?)', encounter_types])
  #   encounter_types_hash = encounter_types.inject({}) {|result, row| result[row.encounter_type_id] = row.name; result }
  #   with_scope(:find => opts) do
  #     rows = self.all(
  #        :select => 'count(*) as number, encounter_type',
  #        :group => 'encounter.encounter_type',
  #        :conditions => ['encounter_type IN (?)', encounter_types.map(&:encounter_type_id)])
  #     return rows.inject({}) {|result, row| result[encounter_types_hash[row['encounter_type']]] = row['number']; result }
  #   end
  # end

  # def self.visits_by_day(start_date,end_date)
  #   required_encounters = ["ART ADHERENCE", "ART_FOLLOWUP",   "ART_INITIAL",
  #                          "ART VISIT",     "HIV RECEPTION",  "HIV STAGING",
  #                          "PART_FOLLOWUP", "PART_INITIAL",   "VITALS"]

  #   required_encounters_ids = required_encounters.inject([]) do |encounters_ids, encounter_type|
  #     encounters_ids << EncounterType.find_by_name(encounter_type).id rescue nil
  #     encounters_ids
  #   end

  #   required_encounters_ids.sort!

  #   Encounter.find(:all,
  #     :joins      => ["INNER JOIN obs     ON obs.encounter_id    = encounter.encounter_id",
  #                     "INNER JOIN patient ON patient.patient_id  = encounter.patient_id"],
  #     :conditions => ["obs.voided = 0 AND encounter_type IN (?) AND encounter_datetime >=? AND encounter_datetime <=?",required_encounters_ids,start_date,end_date],
  #     :group      => "encounter.patient_id,DATE(encounter_datetime)",
  #     :order      => "encounter.encounter_datetime ASC")
  # end

  # def self.select_options
  #   select_options = {
  #    'reason_for_tb_clinic_visit' => [
  #       ['',''],
  #       ['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
  #       ['Smear Positive','SMEAR POSITIVE'],
  #       ['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
  #     ],
  #    'family_planning_methods' => [
  #      ['',''],
  #      ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
  #      ['Depo-Provera', 'DEPO-PROVERA'],
  #      ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
  #      ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
  #      ['Male condoms', 'MALE CONDOMS'],
  #      ['Female condoms', 'FEMALE CONDOMS'],
  #      ['Rhythm method', 'RYTHM METHOD'],
  #      ['Withdrawal', 'WITHDRAWAL'],
  #      ['Abstinence', 'ABSTINENCE'],
  #      ['Tubal ligation', 'TUBAL LIGATION'],
  #      ['Vasectomy', 'VASECTOMY'],
  #      ['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
  #      ['Other','OTHER']
  #     ],
  #    'male_family_planning_methods' => [
  #      ['',''],
  #      ['Male condoms', 'MALE CONDOMS'],
  #      ['Withdrawal', 'WITHDRAWAL'],
  #      ['Rhythm method', 'RYTHM METHOD'],
  #      ['Abstinence', 'ABSTINENCE'],
  #      ['Vasectomy', 'VASECTOMY'],
  #      ['Other','OTHER']
  #     ],
  #    'female_family_planning_methods' => [
  #      ['',''],
  #      ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
  #      ['Depo-Provera', 'DEPO-PROVERA'],
  #      ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
  #      ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
  #      ['Female condoms', 'FEMALE CONDOMS'],
  #      ['Withdrawal', 'WITHDRAWAL'],
  #      ['Rhythm method', 'RYTHM METHOD'],
  #      ['Abstinence', 'ABSTINENCE'],
  #      ['Tubal ligation', 'TUBAL LIGATION'],
  #      ['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
  #      ['Other','OTHER']
  #     ],
  #    'drug_list' => [
  #         ['',''],
  #         ["Rifampicin Isoniazid Pyrazinamide and Ethambutol", "RHEZ (RIF, INH, Ethambutol and Pyrazinamide tab)"],
  #         ["Rifampicin Isoniazid and Ethambutol", "RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t"],
  #         ["Rifampicin and Isoniazid", "RH (Rifampin and Isoniazid tablet)"],
  #         ["Stavudine Lamivudine and Nevirapine", "D4T+3TC+NVP"],
  #         ["Stavudine Lamivudine + Stavudine Lamivudine and Nevirapine", "D4T+3TC/D4T+3TC+NVP"],
  #         ["Zidovudine Lamivudine and Nevirapine", "AZT+3TC+NVP"]
  #     ],
  #       'presc_time_period' => [
  #         ["",""],
  #         ["1 month", "30"],
  #         ["2 months", "60"],
  #         ["3 months", "90"],
  #         ["4 months", "120"],
  #         ["5 months", "150"],
  #         ["6 months", "180"],
  #         ["7 months", "210"],
  #         ["8 months", "240"]
  #     ],
  #       'continue_treatment' => [
  #         ["",""],
  #         ["Yes", "YES"],
  #         ["DHO DOT site","DHO DOT SITE"],
  #         ["Transfer Out", "TRANSFER OUT"]
  #     ],
  #       'hiv_status' => [
  #         ['',''],
  #         ['Negative','NEGATIVE'],
  #         ['Positive','POSITIVE'],
  #         ['Unknown','UNKNOWN']
  #     ],
  #     'who_stage1' => [
  #       ['',''],
  #       ['Asymptomatic','ASYMPTOMATIC'],
  #       ['Persistent generalised lymphadenopathy','PERSISTENT GENERALISED LYMPHADENOPATHY'],
  #       ['Unspecified stage 1 condition','UNSPECIFIED STAGE 1 CONDITION']
  #     ],
  #     'who_stage2' => [
  #       ['',''],
  #       ['Unspecified stage 2 condition','UNSPECIFIED STAGE 2 CONDITION'],
  #       ['Angular cheilitis','ANGULAR CHEILITIS'],
  #       ['Popular pruritic eruptions / Fungal nail infections','POPULAR PRURITIC ERUPTIONS / FUNGAL NAIL INFECTIONS']
  #     ],
  #     'who_stage3' => [
  #       ['',''],
  #       ['Oral candidiasis','ORAL CANDIDIASIS'],
  #       ['Oral hairly leukoplakia','ORAL HAIRLY LEUKOPLAKIA'],
  #       ['Pulmonary tuberculosis','PULMONARY TUBERCULOSIS'],
  #       ['Unspecified stage 3 condition','UNSPECIFIED STAGE 3 CONDITION']
  #     ],
  #     'who_stage4' => [
  #       ['',''],
  #       ['Toxaplasmosis of the brain','TOXAPLASMOSIS OF THE BRAIN'],
  #       ["Kaposi's Sarcoma","KAPOSI'S SARCOMA"],
  #       ['Unspecified stage 4 condition','UNSPECIFIED STAGE 4 CONDITION'],
  #       ['HIV encephalopathy','HIV ENCEPHALOPATHY']
  #     ],
  #     'tb_xray_interpretation' => [
  #       ['',''],
  #       ['Consistent of TB',''],
  #       ['Not Consistent of TB','']
  #     ],
  #     'lab_orders' =>{
  #       "Blood" => ["Full blood count", "Malaria parasite", "Group & cross match", "Urea & Electrolytes", "CD4 count", "Resistance",
  #           "Viral Load", "Cryptococcal Antigen", "Lactate", "Fasting blood sugar", "Random blood sugar", "Sugar profile",
  #           "Liver function test", "Hepatitis test", "Sickling test", "ESR", "Culture & sensitivity", "Widal test", "ELISA",
  #           "ASO titre", "Rheumatoid factor", "Cholesterol", "Triglycerides", "Calcium", "Creatinine", "VDRL", "Direct Coombs",
  #           "Indirect Coombs", "Blood Test NOS"],
  #       "CSF" => ["Full CSF analysis", "Indian ink", "Protein & sugar", "White cell count", "Culture & sensitivity"],
  #       "Urine" => ["Urine microscopy", "Urinanalysis", "Culture & sensitivity"],
  #       "Aspirate" => ["Full aspirate analysis"],
  #       "Stool" => ["Full stool analysis", "Culture & sensitivity"],
  #       "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)"],
  #       "Culture" => ["Culture(1st)", "Culture(2st)"],
  #       "Swab" => ["Microscopy", "Culture & sensitivity"]
  #     },
  #     'tb_symptoms' => [
  #       ['',''],
  #       ["Cough lasting more than three weeks", "Cough lasting more than three weeks"],
  #       ["Bronchial breathing", "Bronchial breathing"],
  #       ["Shortness of breath", "Shortness of breath"],
  #       ["Crackles", "Crackles"],
  #       ["Failure to thrive", "Failure to thrive"],
  #       ["Chest pain", "Chest pain"],
  #       ["Weight loss", "Weight loss"],
  #       ["Relapsing fever", "Relapsing fever"],
  #       ["Fatigue", "Fatigue"],
  #       ["Bloody cough", "Hemoptysis"],
  #       ["Peripheral neuropathy","Peripheral neuropathy"]
  #     ],
  #     'drug_related_side_effects' => [
  #       ['',''],
  #       ["Deafness", "Deafness"],
  #       ["Dizziness", "Dizziness"],
  #       ["Yellow eyes", "Jaundice"],
  #       ["Skin itching/purpura", "Skin itching"],
  #       ["Visual impairment", "Visual impairment"],
  #       ["Vomiting", "Vomiting"],
  #       ["Confusion", "Confusion"],
  #       ["Peripheral neuropathy","Peripheral neuropathy"]
  #     ],
  #     'tb_patient_categories' => [
  #       ['',''],
  #       ["New", "New patient"],
  #       ["Relapse", "Relapse MDR-TB patient"],
  #       ["Retreatment after default", "Treatment after default MDR-TB patient"],
  #       ["Failure", "Failed - TB"]
  #     ]
  #   }
  # end

  # def self.get_previous_encounters(patient_id)
  #   previous_encounters = self.all(
  #             :conditions => ["encounter.voided = ? and patient_id = ?", 0, patient_id],
  #             :include => [:observations]
  #           )

  #   return previous_encounters
  # end

  # #form art

  # def self.lab_activities
  #   lab_activities = [
  #     ['Lab Orders', 'lab_orders'],
  #     ['Sputum Submission', 'sputum_submission'],
  #     ['Lab Results', 'lab_results'],
  #   ]
  # end
end
