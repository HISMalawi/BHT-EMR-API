class NtpRegimen < VoidableRecord
  self.table_name = 'ntp_regimens'
  self.primary_key = 'regimen_id'
  #Drug Name, Units, Concept name
  belongs_to :drug, foreign_key: :drug_inventory_id


  def as_json(options = {})
    super(options.merge(
      include: {
        drug: {}
      }
    ))
  end
  # def drugs
  #   drug = Drug.find_by(drug_id: drug_inventory_id)
  #   p drug
  # end
end


 #regimen_id, [dose as boolean], drug_id, min_weight, max_weight, creator, date_created, retired, retired_by, date_retired

 #just add table database and link the together after to be selectable from the backend
 
#migration file

#MohRegimenIngredient

#Rifampicin (R)  RHZ 75/50/150 (update or add this) && RH - R150 H75
# +------------+---------+----------------------------------------------------+----------------------------------------------+
    # | concept_id | drug_id | name                                               | name                                         |
    # +------------+---------+----------------------------------------------------+----------------------------------------------+
    # |        767 |      16 | RIF or R (Rifampin 300mg tablet)                   | Rifampicin                                   |
    # |        768 |      17 | RHZ (R60/H60/Z150)                                 | Rifampicin isoniazid and pyrazinamide        |
    # |       1131 |      18 | RHZE (R150/H75/Z400)                               | Rifampicin Isoniazid Pyrazinamide Ethambutol |
    # |       1194 |      19 | RH (R150/H75)                                      | Rifampicin and isoniazid                     |
    # |        767 |      44 | RIF or R (Rifampin) no dose strength               | Rifampicin                                   |
    # |       1614 |      88 | RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t | Rifampicin Isoniazid and Ethambutol          |
    # |       1194 |     740 | RH (R60/H30)                                       | Rifampicin and isoniazid                     |
    # +------------+---------+----------------------------------------------------+----------------------------------------------+

    
#Isoniazid (H) RH 75/50 && RHZE - R150 H75 Z400 E275 (update this or add)

#     mysql> select c.concept_id, d.drug_id, d.name, cn.name from drug d, concept c, concept_name cn where d.concept_id = c.concept_id and cn.concept_id = c.concept_id and cn.name like '%Isoniazid%';
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# | concept_id | drug_id | name                                               | name                                         |
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# |        768 |      17 | RHZ (R60/H60/Z150)                                 | Rifampicin isoniazid and pyrazinamide        |
# |       1131 |      18 | RHZE (R150/H75/Z400)                               | Rifampicin Isoniazid Pyrazinamide Ethambutol |
# |       1194 |      19 | RH (R150/H75)                                      | Rifampicin and isoniazid                     |
# |        656 |      24 | INH or H (Isoniazid 100mg tablet)                  | Isoniazid                                    |
# |        656 |      43 | INH or H (Isoniazid) no dose strength              | Isoniazid                                    |
# |       1614 |      88 | RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t | Rifampicin Isoniazid and Ethambutol          |
# |       1194 |     740 | RH (R60/H30)                                       | Rifampicin and isoniazid                     |
# |        656 |     931 | INH or H (Isoniazid 300mg tablet)                  | Isoniazid                                    |
# |        656 |     965 | INH or H (Isoniazid 150mg tablet)                  | Isoniazid                                    |
# |        656 |     966 | INH or H (Isoniazid 200mg tablet)                  | Isoniazid                                    |
# |        656 |     967 | INH or H (Isoniazid 250mg tablet)                  | Isoniazid                                    |
# +------------+---------+----------------------------------------------------+----------------------------------------------+

#Ethambutol (E) RHZE - R150 H75 Z400 E275 (update this or add)

# mysql> select c.concept_id, d.drug_id, d.name, cn.name from drug d, concept c, concept_name cn where d.concept_id = c.concept_id and cn.concept_id = c.concept_id and cn.name like '%Ethambutol%';
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# | concept_id | drug_id | name                                               | name                                         |
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# |       1131 |      18 | RHZE (R150/H75/Z400)                               | Rifampicin Isoniazid Pyrazinamide Ethambutol |
# |        745 |      27 | E (Ethambutol 400mg tablet)                        | Ethambutol                                   |
# |        745 |      45 | E (Ethambutol) no dose strength                    | Ethambutol                                   |
# |       1614 |      88 | RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t | Rifampicin Isoniazid and Ethambutol          |
# |        745 |     103 | E (Ethambutol 100mg tablet)                        | Ethambutol                                   |
# +------------+---------+----------------------------------------------------+----------------------------------------------+


#Ethambutol (E) OK - 
# E 100 drug_id 103
# mysql> select c.concept_id, d.drug_id, d.name, cn.name from drug d, concept c, concept_name cn where d.concept_id = c.concept_id and cn.concept_id = c.concept_id and cn.name like '%Ethambutol%';
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# | concept_id | drug_id | name                                               | name                                         |
# +------------+---------+----------------------------------------------------+----------------------------------------------+
# |       1131 |      18 | RHZE (R150/H75/Z400)                               | Rifampicin Isoniazid Pyrazinamide Ethambutol |
# |        745 |      27 | E (Ethambutol 400mg tablet)                        | Ethambutol                                   |
# |        745 |      45 | E (Ethambutol) no dose strength                    | Ethambutol                                   |
# |       1614 |      88 | RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t | Rifampicin Isoniazid and Ethambutol          |
# |        745 |     103 | E (Ethambutol 100mg tablet)                        | Ethambutol                                   |
# +------------+---------+----------------------------------------------------+----------------------------------------------+

#RH - R150 H75
#(R150/H75) OK