class AddDtgToRegimen12A < ActiveRecord::Migration[5.2]
  def up
    User.current = User.first
    Location.current = Location.first

    # Delete drugs removed in 2018 ART guide lines
    MohRegimenIngredient.where(
      regimen_id: 11,
      drug_inventory_id: [954, 978] # RAL (Raltegravir 400mg) and Etravirine 100mg respectively where removed
    ).each(&:delete)

    MohRegimenIngredient.create drug_inventory_id: 982, # 982 is DTG 50
                                regimen_id: 11, # Regimen 12 is mapped to regimen_id 11
                                dose_id: 6, # Dose 6 is { am: 0, pm: 1 }
                                min_weight: 30,
                                max_weight: 300,
                                gender: 'MF',
                                date_created: Time.now
  end

  def down
    User.current = User.first
    Location.current = Location.first

    # Restore deleted drugs
    [954, 978].each do |drug_id|
      MohRegimenIngredient.create drug_inventory_id: drug_id,
                                  regimen_id: 11, # Regimen 12 is mapped to regimen_id 11
                                  dose_id: 6, # Dose 6 is { am: 0, pm: 1 }
                                  min_weight: 30,
                                  max_weight: 300,
                                  gender: 'MF',
                                  date_created: Time.now
    end

    ingredient = MohRegimenIngredient.find_by drug_inventory_id: 982,
                                              regimen_id: 11,
                                              dose_id: 6,
                                              min_weight: 30,
                                              max_weight: 300,
                                              gender: 'MF'
    ingredient&.delete
  end
end
