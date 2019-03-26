# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])

# insert into drug (concept_id, name, combination, dose_strength, units, creator, uuid)
# VALUES
# (768, 'RHZ (R75/H50/Z150)', 1, 1, 'mg', 1, 'a'),
# (1194, 'RH (R75/H50)', 1, 1, 'mg', 1, 'b'),
# (1131, 'RHZE (R150/H75/Z400/E275)', 1, 1, 'mg', 1, 'c');

#TB Drugs
Drug.where(concept_id: 768, name: 'RHZ (R75/H50/Z150)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid ).first_or_create
Drug.where(concept_id: 1194, name: 'RH (R75/H50)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid ).first_or_create
Drug.where(concept_id: 1131, name: 'RHZE (R150/H75/Z400/E275)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid ).first_or_create

#Regimens: RHZE (R150/H75/Z400/E275) && RH (R150/H75)
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 1, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 1, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 1, min_weight: 16, max_weight: 24, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 1, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 1, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 1, min_weight: 16, max_weight: 24, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 1, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 1, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 1, min_weight: 16, max_weight: 24, creator: 1).first_or_create

#Adult Regimens: RHZE (R150/H75/Z400/E275) && RH (R150/H75)
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 1, min_weight: 30, max_weight: 37, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 1, min_weight: 38, max_weight: 54, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 1, min_weight: 55, max_weight: 74, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 1, min_weight: 75, max_weight: 1000, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 1, min_weight: 30, max_weight: 37, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 1, min_weight: 38, max_weight: 54, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 1, min_weight: 55, max_weight: 74, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 1, min_weight: 75, max_weight: 1000, creator: 1).first_or_create


