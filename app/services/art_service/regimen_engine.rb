# frozen_string_literal: true

require 'set'

module ARTService
  # TODO: This module reads like noise, it needs a re-write or even better,
  #       a complete rewrite.
  class RegimenEngine
    include ModelUtils

    LOGGER = Rails.logger

    def initialize(program:)
      @program = program
    end

    def self.arv_drugs
      # TODO: Get rid of the arv_drugs method in Drug model
      Drug.arv_drugs
    end

    # Returns all drugs that can be combined to form custom ART regimens
    def custom_regimen_ingredients
      arv_extras_concepts = Concept.joins(:concept_names).where(
        concept_name: { name: %w[INH CPT Pyridoxine Rifapentine] }
      )
      Drug.where(concept: arv_extras_concepts) + Drug.arv_drugs.order(name: :desc)
    end

    def regimen_extras(patient_weight, name = nil)
      name = %w[INH Pyridoxine] if name&.casecmp?('INH') # INH is always paired with pyridoxine
      name ||= %w[Pyridoxine INH CPT]

      drug_id ||= Drug.where(concept: Concept.joins(:concept_names)
                                             .merge(ConceptName.where(name: name)))
                      .select(:drug_id)
                      .map(&:drug_id)

      ingredients = MohRegimenIngredient.where(drug_inventory_id: drug_id)
                                        .where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                                AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                               weight: patient_weight.to_f)

      ingredients.map { |ingredient| ingredient_to_drug(ingredient) }
    end

    def find_starter_pack(regimen, weight)
      ingredients = MohRegimenIngredientStarterPack.joins(:regimen).where(
        moh_regimens: { regimen_index: regimen }
      ).where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
               AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
              weight: weight.to_f.round(1))
      ingredients.collect { |ingredient| ingredient_to_drug(ingredient) }
    end

    def find_regimens_by_patient(patient, lpv_drug_type: 'tabs')
      use_tb_dosage = use_tb_patient_dosage?(dtg_drugs.first, patient)
      find_regimens(patient.weight, use_tb_dosage: use_tb_dosage,
                                    lpv_drug_type: lpv_drug_type)
    end

    def find_regimens(patient_weight, use_tb_dosage: false, lpv_drug_type: 'tabs')
      ingredients = MohRegimenIngredient.where(
        '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
         AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
        weight: patient_weight.to_f.round(1)
      )

      raw_regimens = regimens_from_ingredients(ingredients, lpv_drug_type: lpv_drug_type)
      regimens = categorise_regimens(raw_regimens)

      if use_tb_dosage
        repackage_regimens_for_tb_patients!(regimens, patient_weight)
      end

      regimens
    end

    def regimen(patient, regimen_index, lpv_drug_type: 'tabs')
      ingredients = MohRegimenIngredient.joins(:regimen)\
                                        .where(moh_regimens: { regimen_index: regimen_index })\
                                        .where(
                                          '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
                                          weight: patient.weight.to_f.round(1)
                                        )

      regimens_from_ingredients(ingredients, lpv_drug_type: lpv_drug_type, patient: patient)
    end

    # Returns dosages for a patients prescribed medication courses
    def find_dosages(patient, date = Date.today)
      # Make sure it has been stated explicitly that drugs are getting prescribed
      # to this patient
      return {} unless patient_getting_prescription?(patient, date)

      courses = parallel_drug_courses.select(%i[concept_id name])

      find_course = lambda do |concept_id|
        courses.find { |course| course.concept_id == concept_id }
      end

      prescriptions = patient_course_prescriptions(patient, date, courses)

      prescribed_courses = courses.select do |course|
        prescriptions.find { |prescription| prescription.value_coded.to_i == course.concept_id }
      end

      prescriptions.each_with_object({}) do |prescription, dosages|
        course = find_course.call(prescription.value_coded.to_i)
        drugs = find_drugs_by_course(course)

        dominant_course_name = select_dominant_course_name(course, prescribed_courses)

        ingredients = find_regimen_ingredients(weight: patient.weight, drugs: drugs, course: dominant_course_name)

        ingredients.each do |ingredient|
          drug_name = ConceptName.find_by(concept_id: ingredient.drug.concept_id).name
          dosages[drug_name] = ingredient_to_drug(ingredient)
        end
      end
    end

    private

    # Packs a list of regimen ingredients into a map of
    # regimen id to regimens.
    #
    # NOTE: A regimen is just the following structure:
    #   {
    #     index: xx
    #     drug: {...},
    #     am: xx,
    #     pm: xx,
    #     category: xx
    #   }
    def regimens_from_ingredients(ingredients, lpv_drug_type: 'tabs', patient: nil)
      ingredients.each_with_object({}) do |ingredient, regimens|
        # Have some CPT & INH that do not belong to any regimen
        # but have a weight - dosage mapping hence being lumped
        # together with the regimen ingredients
        next unless ingredient.regimen

        regimen_index = ingredient.regimen.regimen_index
        regimen = regimens[regimen_index] || []

        drug_name = ingredient.drug.name

        if %r{^LPV/r}.match?(drug_name)\
            && ((lpv_drug_type == 'tabs' && find_drug_type(ingredient.drug) != 'tabs')\
                || (%w[pellets granules].include?(lpv_drug_type)\
                    && find_drug_type(ingredient.drug) != lpv_drug_type))
          # LPV/r comes in three forms tabs, pills, or granules. Clinician specifies
          # which form to prescribe thus we skip the unwanted drugs.
          LOGGER.debug("Skipping non #{lpv_drug_type}, #{drug_name}...")
          next
        end

        regimen << ingredient_to_drug(ingredient)

        regimens[regimen_index] = regimen
      end
    end

    def categorise_regimens(regimens)
      regimens.values.each_with_object({}) do |drugs, categorised_regimens|
        Rails.logger.debug "Interpreting drug list: #{drugs.collect { |drug| [drug[:drug_id], drug[:drug_name]] }}"
        (0...drugs.size).each do |pivot|
          (pivot...drugs.size).each do |combo_start|
            (combo_start..drugs.size).each do |combo_end|
              trial_regimen = [drugs[pivot], *drugs[combo_start...combo_end]]

              regimen_name = classify_regimen_combo(trial_regimen.map { |t| t[:drug_id] })
              next unless regimen_name

              categorised_regimens[regimen_name] = Set.new(trial_regimen)
            end
          end
        end
      end
    end

    def ingredient_to_drug(ingredient)
      drug = ingredient.drug
      regimen_category_lookup = MohRegimenLookup.find_by(drug_inventory_id: ingredient.drug_inventory_id)
      regimen_category = regimen_category_lookup ? regimen_category_lookup.regimen_name[-1] : nil

      {
        drug_id: drug.drug_id,
        concept_id: drug.concept_id,
        drug_name: drug.name,
        alternative_drug_name: drug.alternative_names.first&.short_name,
        am: ingredient.dose.am,
        noon: 0, # Requested by the frontenders
        pm: ingredient.dose.pm,
        units: drug.units,
        concept_name: drug.concept.concept_names[0].name,
        pack_size: drug.drug_cms ? drug.drug_cms.pack_size : nil,
        barcodes: drug.barcodes.collect { |barcode| { tabs: barcode.tabs } },
        regimen_category: regimen_category
      }
    end

    def use_tb_patient_dosage?(drug, patient)
      dtg_concept_id = ConceptName.find_by(name: 'Dolutegravir').concept_id

      return false unless patient && drug.concept_id == dtg_concept_id

      tb_status_concept_id = ConceptName.find_by_name('TB Status').concept_id
      on_tb_treatment_concept_ids = ConceptName.where(name: 'RX').collect(&:concept_id)

      tb_status_max = Observation.joins(:encounter)\
                                              .where(person_id: patient.id,
                                                     concept_id: tb_status_concept_id)\
                                              .select('MAX(obs_datetime) AS obs_datetime')

      tb_status_max_datetime = tb_status_max.first&.obs_datetime&.to_time
      return false unless tb_status_max_datetime

      patient_is_on_tb_treatment = Observation.joins(:encounter)\
                                              .where(person_id: patient.id,
                                                     concept_id: tb_status_concept_id,
                                                     obs_datetime: tb_status_max_datetime,
                                                     encounter: {
                                                       program_id: @program.program_id
                                                     })\
                                              .order('obs_datetime DESC')
                                              .limit(1)

      return false if patient_is_on_tb_treatment.blank?
      return false unless on_tb_treatment_concept_ids.include?(patient_is_on_tb_treatment.first.value_coded)

      return drug.concept_id == dtg_concept_id
    end

    def regimen_interpreter(medication_ids = [])
      Rails.logger.debug "Interpreting regimen: #{medication_ids}"
      regimen_name = nil

      REGIMEN_CODES.each do |regimen_code, data|
        data.each do |row|
          drugs = [row].flatten
          drug_ids = Drug.where(['drug_id IN (?)', drugs]).map(&:drug_id)
          if ((drug_ids - medication_ids) == []) && (drug_ids.count == medication_ids.count)
            regimen_name = regimen_code
            break
          end
        end
      end

      Rails.logger.warn "Failed to Interpret regimen: #{medication_ids}" unless regimen_name

      regimen_name
    end

    # An alternative to the regimen_interpreter method above...
    # This achieves the same as that method without hitting the database
    def classify_regimen_combo(drug_combo)
      Rails.logger.debug "Interpreting regimen: #{drug_combo}"

      drug_combo = Set.new drug_combo
      REGIMEN_CODES.each do |regimen_index, combos|
        combos.each do |combo|
          return regimen_category(drug_combo, regimen_index) if combo == drug_combo
        end
      end

      Rails.logger.warn "Failed to Interpret regimen: #{drug_combo}"

      nil
    end

    # Analyses the drugs in list, @{param drug_combo}, and returns a regimen category
    # the drugs belong to (eg. 9P or 9A).
    #
    # Example:
    #   > regimen_category(drug_combo, '5') # For all adult drugs
    #   => '5A'
    #   > regimen_category(drug_combo, '2')  # At least one of the drugs is paed.
    #   => '2P'
    def regimen_category(drug_combo, prefix)
      prefix = prefix.to_s

      drug_combo.reduce(nil) do |category, drug|
        return category if category && category[-1]&.casecmp?('P')

        lookup = MohRegimenLookup.where(drug_inventory_id: drug).first
        next category unless lookup

        prefix + lookup.regimen_name[-1]
      end
    end

    # Age at which we assuming women lose their child bearing capability
    FEMALE_INFECUNDITY_ONSET_AGE = 45

    # Retrieves an adjusted patient age for look up into MohRegimenIngredients table.
    #
    # NOTE: Method pushes age up to 45 for women on permanent family planning
    # method and adjusts it downwards to 44 for women above 45 and pregnant.
    def adjusted_patient_age(patient)
      return patient.age if patient.gender.upcase.start_with?('M')

      return FEMALE_INFECUNDITY_ONSET_AGE if patient_on_permanent_fp_method?(patient)

      return FEMALE_INFECUNDITY_ONSET_AGE - 1 if patient_is_pregnant?(patient)

      patient.age
    end

    # Checks if patient is on permanent family planning method.
    #
    # NOTE: Only applies to females
    def patient_on_permanent_fp_method?(patient)
      permanent_fp_concepts = [concept('Hysterectomy'), concept('Tubal ligation')]
      Observation.where(concept: permanent_fp_concepts, person: patient.person).exists?
    end

    def patient_is_pregnant?(patient)
      pregnant_concept = concept('Is Patient Pregnant?')
      obs = Observation.where(
        concept: pregnant_concept,
        person: patient.person
      ).order(obs_datetime: :desc).first

      return false unless obs

      obs.value_coded == concept('Yes').concept_id
    end

    # Repackages some regimens for patients on TB treatment.
    #
    # Patient's on TB treatment require custom prescriptions for DTG
    # than what is prescribed normally. This function takes a regimens
    # structure and repackages the relevant regimens.
    def repackage_regimens_for_tb_patients!(regimens, patient_weight)
      %w[12A 13A 14A 15A].each do |regimen_name|
        regimen = regimens[regimen_name]
        next unless regimen

        if regimen_name == '13A'
          inject_dtg_into_regimen!(regimen, patient_weight)
        else
          double_dose_dtg_in_regimen!(regimen)
        end
      end
    end

    def dtg_drugs
      @dtg_drugs ||= Drug.where(concept: concept('Dolutegravir'))
    end

    # Doubles the daily dosage for DTG if present in the regimen.
    def double_dose_dtg_in_regimen!(regimen)
      @dtg_drug_ids ||= dtg_drugs.collect(&:drug_id)

      regimen.each do |drug|
        next unless @dtg_drug_ids.include?(drug[:drug_id])

        drug[:pm] = drug[:am]
      end
    end

    # Adds DTG to the regimen for the non-standard double dosing of
    # drugs containing a DTG component (eg 13A).
    def inject_dtg_into_regimen!(regimen, patient_weight)
      @dtg_drug_ids ||= dtg_drugs.collect(&:drug_id)

      dtg_ingredient = MohRegimenIngredient.where(
        'drug_inventory_id IN (:drugs) AND CAST(min_weight AS DECIMAL(4, 1)) <= :weight
          AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
        drugs: @dtg_drug_ids,
        weight: patient_weight
      ).first

      dtg = ingredient_to_drug(dtg_ingredient)

      # Normally DTG is taken in the morning, it has to be inverted...
      dtg[:am], dtg[:pm] = dtg[:pm], dtg[:am]

      regimen << dtg
    end

    def find_drug_type(drug)
      if drug.name.match?(/\s+pellets\s*/i)
        'pellets'
      elsif drug.name.match?(/\s+granules\s*/i)
        'granules'
      else
        'tabs'
      end
    end

    # Checks if it has been explicitly specified that a patient is getting
    # a prescription on the given date.
    def patient_getting_prescription?(patient, date)
      Observation.where(person_id: patient.patient_id,
                        concept_id: ConceptName.find_by_name('Prescribe drugs').concept_id,
                        value_coded: ConceptName.find_by_name('Yes').concept_id)\
                 .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                 .exists?
    end

    # Returns prescriptions for medication courses a patient is to receive
    # on a given date.
    def patient_course_prescriptions(patient, date, courses = nil)
      query = Observation.where(concept: ConceptName.find_by_name('Medication orders').concept_id,
                                person_id: patient.id)
                         .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      return query unless courses

      query.where(value_coded: courses.collect(&:concept_id))
    end

    # Returns drug courses (as concepts) that are offered alongside the primary
    # ART regimen course
    def parallel_drug_courses
      ConceptName.where(name: %w[CPT INH Rifapentine])
    end

    # Returns the name of the dominant course among the given courses.
    #
    # Method compares primary_course to the rest of courses for an
    # overlapping dominant course.
    #
    # NOTE: Courses can contain same drugs but with different dosages.
    # For example 3HP and IPT both have INH with different dosages however.
    def select_dominant_course_name(primary_course, courses)
      # Currently this dominant course resolution is needed for 3HP vs INH only
      # thus we are simply returning 3HP (Rifapentine) or nothing.
      case primary_course.name.downcase
      when 'rifapentine' then '3HP'
      when 'inh' then courses.find { |course| course.name.casecmp?('rifapentine') } && '3HP'
      end
    end

    # Retrieves drugs that make up the given medication course.
    #
    # Examples:
    #   Course(INH) => {INH, Pyridoxine}
    #   Course(Rifapentine) => {Rifapentine, INH} //
    #
    #   NOTE: The courses above should rightly be called IPT and 3HP but historically
    #         they were being wrongly named in the application by their primary
    #         ingredient name.
    def find_drugs_by_course(drug_concept)
      if drug_concept.name == 'INH' # IPT Course
        Drug.where(concept: [drug_concept.concept_id, ConceptName.find_by_name('Pyridoxine').concept_id])
      elsif drug_concept.name == 'Rifapentine' # 3HP Course
        Drug.where(concept: [drug_concept.concept_id, ConceptName.find_by_name('Isoniazid').concept_id])
      else
        Drug.where(concept: drug_concept.concept_id)
      end
    end

    def find_regimen_ingredients(weight: nil, drugs: nil, course: nil)
      query = MohRegimenIngredient.where(course: course)
      query = query.where(drug: drugs) if drugs

      return query unless weight

      query.where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                   AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                  weight: weight.to_f.round(1))
    end

    REGIMEN_CODES = {
      # ABC/3TC (Abacavir and Lamivudine 60/30mg tablet) = 733
      # NVP (Nevirapine 50 mg tablet) = 968
      # NVP (Nevirapine 200 mg tablet) = 22
      # ABC/3TC (Abacavir and Lamivudine 600/300mg tablet) = 969
      # AZT/3TC/NVP (60/30/50mg tablet) = 732
      # AZT/3TC/NVP (300/150/200mg tablet) = 731
      # AZT/3TC (Zidovudine and Lamivudine 60/30 tablet) = 736
      # EFV (Efavirenz 200mg tablet) = 30
      # EFV (Efavirenz 600mg tablet) = 11
      # AZT/3TC (Zidovudine and Lamivudine 300/150mg) = 39
      # TDF/3TC/EFV (300/300/600mg tablet) = 735
      # TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet = 734
      # ATV/r (Atazanavir 300mg/Ritonavir 100mg) = 932
      # LPV/r (Lopinavir and Ritonavir 100/25mg tablet) = 74
      # LPV/r (Lopinavir and Ritonavir 200/50mg tablet) = 73
      # Darunavir 600mg = 976
      # Ritonavir 100mg = 977
      # Etravirine 100mg = 978
      # RAL (Raltegravir 400mg) = 954
      # NVP (Nevirapine 200 mg tablet) = 22
      # LPV/r pellets = 979
      '0' => [Set.new([1044, 968]), Set.new([1044, 22]), Set.new([969, 22]), Set.new([969, 968])],
      '2' => [Set.new([732]), Set.new([732, 736]), Set.new([732, 39]), Set.new([731]), Set.new([731, 39]), Set.new([731, 736])],
      '4' => [Set.new([736, 30]), Set.new([736, 11]), Set.new([39, 11]), Set.new([39, 30])],
      '5' => [Set.new([735])],
      '6' => [Set.new([734, 22])],
      '7' => [Set.new([734, 932])],
      '8' => [Set.new([39, 932])],
      '9' => [Set.new([1044, 74]), Set.new([1044, 73]), Set.new([969, 73]), Set.new([969, 74]), Set.new([1044, 979])],
      '10' => [Set.new([734, 73])],
      '11' => [Set.new([736, 74]), Set.new([736, 73]), Set.new([736, 1044]), Set.new([39, 73]), Set.new([39, 74])],
      '12' => [Set.new([976, 977, 982])],
      '13' => [Set.new([983])],
      '14' => [Set.new([736, 982]), Set.new([984, 982])],
      '15' => [Set.new([1044, 982]), Set.new([969, 982])],
      '16' => [Set.new([1043, 1044]), Set.new([954,969])],
      '17' => [Set.new([30,1044]), Set.new([11,969])]
    }.freeze
  end
end
