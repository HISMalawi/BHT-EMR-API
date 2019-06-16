# frozen_string_literal: true

require 'set'

module ARTService
  # TODO: This module reads like noise, it needs a re-write or even better,
  #       a complete rewrite.
  class RegimenEngine
    include ModelUtils

    def initialize(program:)
      @program = program
    end

    # Returns all drugs that can be combined to form custom ART regimens
    def custom_regimen_ingredients
      arv_extras_concepts = Concept.joins(:concept_names).where(
        concept_name: { name: %w[INH CPT Pyridoxine] }
      )
      Drug.where(concept: arv_extras_concepts) + Drug.arv_drugs.order(name: :desc)
    end

    def find_starter_pack(regimen, weight)
      ingredients = MohRegimenIngredientStarterPack.joins(:regimen).where(
        moh_regimens: { regimen_index: regimen }
      ).where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
               AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
              weight: weight.to_f.round(1))
      ingredients.collect { |ingredient| ingredient_to_drug(ingredient) }
    end

    def find_regimens(patient, pellets: false)
      ingredients = MohRegimenIngredient.where(
        '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
         AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
        weight: patient.weight.to_f.round(1)
      )

      categorise_regimens(regimens_from_ingredients(ingredients, patient: patient))
    end

    def pellets_regimen(patient, regimen_index, use_pellets)
      ingredients = MohRegimenIngredient.joins(:regimen)\
                                        .where(moh_regimens: { regimen_index: regimen_index })\
                                        .where(
                                          '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
                                          weight: patient.weight.to_f.round(1)
                                        )

      regimens_from_ingredients(ingredients, use_pellets: use_pellets, patient: patient)
    end

    # Returns dosages for patients prescribed ARVs
    def find_dosages(patient, date = Date.today)
      # TODO: Refactor this into smaller functions

      # Make sure it has been stated explicitly that drug are getting prescribed
      # to this patient
      prescribe_drugs = Observation.where(person_id: patient.patient_id,
                                          concept_id: ConceptName.find_by_name('Prescribe drugs').concept_id,
                                          value_coded: ConceptName.find_by_name('Yes').concept_id)\
                                   .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                   .order(obs_datetime: :desc)
                                   .first

      return {} unless prescribe_drugs

      arv_extras_concept_ids = [ConceptName.find_by_name('CPT').concept_id, ConceptName.find_by_name('INH').concept_id]

      orders = Observation.where(concept: ConceptName.find_by_name('Medication orders').concept_id,
                                 person: patient.person)
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      orders.each_with_object({}) do |order, dosages|
        next unless order.value_coded # Raise a warning here

        drug_concept_id = order.value_coded.to_i

        next unless arv_extras_concept_ids.include?(drug_concept_id)

        # HACK: Retrieve Pyridoxine 25 mg in addition to Isoniazed when
        # we detect INH drug concept
        drugs = if drug_concept_id == arv_extras_concept_ids[1]
                  Drug.where(concept: [drug_concept_id, ConceptName.find_by_name('Pyridoxine').concept_id])
                else
                  Drug.where(concept: drug_concept_id)
                end

        ingredients = MohRegimenIngredient.where(drug: drugs)\
                                          .where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                                  AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                                 weight: patient.weight.to_f.round(1))

        ingredients.each do |ingredient|
          drug_name = ConceptName.where(concept_id: ingredient.drug.concept_id,
                                        concept_name_type: 'FULLY_SPECIFIED')\
                                 .first
          dosages[drug_name.name] = ingredient_to_drug(ingredient, patient)
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
    def regimens_from_ingredients(ingredients, use_pellets: false, patient: nil)
      # Drug 13A has to be paired with an additional DTG50 for TB patients
      regimen_13a_drug = Drug.find_by_name('TDF300/3TC300/DTG50')
      dtg_drugs = Drug.where(concept: ConceptName.find_by_name('Dolutegravir'))

      ingredients.each_with_object({}) do |ingredient, regimens|
        # Have some CPT & INH that do not belong to any regimen
        # but have a weight - dosage mapping hence being lumped
        # together with the regimen ingredients
        next unless ingredient.regimen

        regimen_index = ingredient.regimen.regimen_index
        regimen = regimens[regimen_index] || []

        drug_name = ingredient.drug.name
        if /^LPV\/r/.match?(drug_name)
          includes_pellets = drug_name.match?(/pellets/i)
          next if (use_pellets && !includes_pellets) || (!use_pellets && includes_pellets)
        end

        regimen << ingredient_to_drug(ingredient, patient)

        # Handle extra 13A DTG for TB patients if needed
        if ingredient.drug_inventory_id == regimen_13a_drug.drug_id\
            && use_tb_patient_dosage?(dtg_drugs[0], patient)
          extra_ingredient = MohRegimenIngredient.where(
            'drug_inventory_id IN (:drugs) AND CAST(min_weight AS DECIMAL(4, 1)) <= :weight
             AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
            drugs: dtg_drugs.collect(&:drug_id),
            weight: patient.weight.to_f
          ).first

          drug = ingredient_to_drug(extra_ingredient, check_tb_patient: false)
          # Normally DTG is taken in the morning, it has to be inverted...
          drug[:am], drug[:pm] = drug[:pm], drug[:am]

          regimen << drug
        end

        regimens[regimen_index] = regimen
      end
    end

    def categorise_regimens(regimens)
      regimens.values.each_with_object({}) do |drugs, categorised_regimens|
        Rails.logger.debug "Interpreting drug list: #{drugs.collect { |drug| drug[:drug_id] }}"
        (0..(drugs.size - 1)).each do |i|
          ((i + 1)..(drugs.size)).each do |j|
            trial_regimen = drugs[i...j]

            regimen_name = classify_regimen_combo(trial_regimen.map { |t| t[:drug_id] })
            next unless regimen_name

            categorised_regimens[regimen_name] = trial_regimen
          end
        end
      end
    end

    def ingredient_to_drug(ingredient, patient = nil, check_tb_patient: true)
      drug = ingredient.drug
      regimen_category_lookup = MohRegimenLookup.find_by(drug_inventory_id: ingredient.drug_inventory_id)
      regimen_category = regimen_category_lookup ? regimen_category_lookup.regimen_name[-1] : nil
      use_tb_patient_dosage = patient && check_tb_patient && use_tb_patient_dosage?(drug, patient)

      {
        drug_id: drug.drug_id,
        concept_id: drug.concept_id,
        drug_name: drug.name,
        alternative_drug_name: drug.alternative_names.first&.short_name,
        am: ingredient.dose.am,
        noon: 0, # Requested by the frontenders
        pm: use_tb_patient_dosage ? ingredient.dose.am : ingredient.dose.pm,
        units: drug.units,
        concept_name: drug.concept.concept_names[0].name,
        pack_size: drug.drug_cms ? drug.drug_cms.pack_size : nil,
        barcodes: drug.barcodes.collect { |barcode| { tabs: barcode.tabs } },
        regimen_category: regimen_category
      }
    end

    def use_tb_patient_dosage?(drug, patient)
      dtg_concept_id = ConceptName.find_by(name: 'Dolutegravir').concept_id

      print "Use TB patient dosage: #{[patient, drug.as_json, dtg_concept_id]}\n"
      return false unless patient && drug.concept_id == dtg_concept_id

      tb_status_concept_id = ConceptName.find_by_name('TB Status').concept_id
      on_tb_treatment_concept_ids = ConceptName.where(name: 'RX').collect(&:concept_id)

      patient_is_on_tb_treatment = Observation.joins(:encounter)\
                                              .where(person_id: patient.id,
                                                     concept_id: tb_status_concept_id)\
                                              .order('obs_datetime DESC').group(:concept_id)

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
      '0' => [Set.new([733, 968]), Set.new([733, 22]), Set.new([969, 22]), Set.new([969, 968])],
      '2' => [Set.new([732]), Set.new([732, 736]), Set.new([732, 39]), Set.new([731]), Set.new([731, 39]), Set.new([731, 736])],
      '4' => [Set.new([736, 30]), Set.new([736, 11]), Set.new([39, 11]), Set.new([39, 30])],
      '5' => [Set.new([735])],
      '6' => [Set.new([734, 22])],
      '7' => [Set.new([734, 932])],
      '8' => [Set.new([39, 932])],
      '9' => [Set.new([733, 979]), Set.new([733, 74]), Set.new([733, 73]), Set.new([969, 73]), Set.new([969, 74])],
      '10' => [Set.new([734, 73])],
      '11' => [Set.new([736, 74]), Set.new([736, 73]), Set.new([39, 73]), Set.new([39, 74])],
      '12' => [Set.new([976, 977, 982])],
      '13' => [Set.new([983, 982]), Set.new([983])],
      '14' => [Set.new([984, 982])],
      '15' => [Set.new([969, 982])]
    }.freeze
  end
end
