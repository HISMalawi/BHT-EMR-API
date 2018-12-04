# frozen_string_literal: true

require 'set'

module ARTService
  class RegimenEngine
    include ModelUtils

    def initialize(program:)
      @program = program
    end

    def find_regimens(patient_age:, patient_weight:, patient_gender:)
      patient_gender = patient_gender.strip[0]

      ingredients = MohRegimenIngredient.where(
        '(min_weight <= :weight and max_weight >= :weight)
         AND (min_age <= :age AND max_age >= :age)
         AND (gender LIKE :gender)',
        weight: patient_weight, age: patient_age, gender: "%#{patient_gender}%"
      )

      categorise_regimens(regimens_from_ingredients(ingredients))
    end

    # Returns dosages for patients prescribed ARVs
    def find_dosages(patient, date = Date.today)
      # TODO: Refactor this into smaller functions

      # Make sure it has been stated explicitly that drug are getting prescribed
      # to this patient
      prescribe_drugs = Observation.where(person_id: patient.patient_id,
                                          concept: concept('Prescribe drugs'),
                                          value_coded: concept('Yes').concept_id)\
                                   .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                   .order(obs_datetime: :desc)
                                   .first

      return {} unless prescribe_drugs

      arv_extras_concepts = [concept('CPT'), concept('INH')]

      orders = Observation.where(concept: concept('Medication orders'))
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      orders.each_with_object({}) do |order, dosages|
        next unless order.value_coded # Raise a warning here

        drug_concept = Concept.find(order.value_coded)

        next unless arv_extras_concepts.include?(drug_concept)

        drugs = Drug.where(concept: drug_concept)

        ingredients = MohRegimenIngredient.where(drug: drugs)\
                                          .where('min_weight <= :weight AND max_weight >= :weight',
                                                 weight: patient.weight)
        dosages[drug_concept.concept_names.first.name] = ingredients.collect(&:dose)
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
    def regimens_from_ingredients(ingredients)
      ingredients.each_with_object({}) do |ingredient, regimens|
        regimen_index = ingredient.regimen.regimen_index
        regimen = regimens[regimen_index] || []

        regimen << ingredient_to_drug(ingredient)
        regimens[regimen_index] = regimen
        # add_category_to_regimen! regimen, ingredient
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

    def ingredient_to_drug(ingredient)
      drug = ingredient.drug
      {
        drug_id: drug.drug_id,
        drug_name: drug.name,
        am: ingredient.dose.am,
        pm: ingredient.dose.pm,
        units: drug.units,
        concept_name: drug.concept.concept_names[0].name,
        pack_size: drug.drug_cms ? drug.drug_cms.pack_size : nil
      }
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
      REGIMEN_CODES.each do |regimen_category, combos|
        combos.each { |combo| return regimen_category if combo == drug_combo }
      end

      Rails.logger.warn "Failed to Interpret regimen: #{drug_combo}"

      nil
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
      '0P' => [Set.new([733, 968]), Set.new([733, 22])],
      '0A' => [Set.new([969, 22]), Set.new([969, 968])],
      '2P' => [Set.new([732]), Set.new([732, 736]), Set.new([732, 39])],
      '2A' => [Set.new([731]), Set.new([731, 39]), Set.new([731, 736])],
      '4P' => [Set.new([736, 30]), Set.new([736, 11])],
      '4A' => [Set.new([39, 11]), Set.new([39, 30])],
      '5A' => [Set.new([735])],
      '6A' => [Set.new([734, 22])],
      '7A' => [Set.new([734, 932])],
      '8A' => [Set.new([39, 932])],
      '9P' => [Set.new([733, 74]), Set.new([733, 73]), Set.new([733, 979])],
      '9A' => [Set.new([969, 73]), Set.new([969, 74])],
      '10A' => [Set.new([734, 73])],
      '11P' => [Set.new([736, 74]), Set.new([736, 73])],
      '11A' => [Set.new([39, 73]), Set.new([39, 74])],
      '12A' => [Set.new([976, 977, 978, 954])],
      '13A' => [Set.new([983])],
      '14A' => [Set.new([984, 982])],
      '15A' => [Set.new([969, 982])]
    }.freeze
  end
end
