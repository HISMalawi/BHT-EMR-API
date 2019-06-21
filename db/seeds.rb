# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])

# TB Drugs
Drug.where(concept_id: 768, name: 'RHZ (R75/H50/Z150)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1194, name: 'RH (R75/H50)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1131, name: 'RHZE (R150/H75/Z400/E275)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

Drug.where(concept_id: 438, name: 'S (Streptomycin 0.50mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'S (Streptomycin 0.75mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'S (Streptomycin 1.00mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

Drug.where(concept_id: 766, name: 'Pyridoxine (25mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 766, name: 'Pyridoxine (50mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 766, name: 'Pyridoxine (150mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

Drug.where(concept_id: 2460, name: 'Rifabutin (150mgs)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Child Regimens:
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 2, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 3, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZ (R75/H50/Z150)'), am_dose: 4, min_weight: 16, max_weight: 24, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 2, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 3, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R75/H50)'), am_dose: 4, min_weight: 16, max_weight: 24, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 1, min_weight: 4, max_weight: 7, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 2, min_weight: 8, max_weight: 11, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 3, min_weight: 12, max_weight: 15, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'E (Ethambutol 100mg tablet)'), am_dose: 4, min_weight: 16, max_weight: 24, creator: 1).first_or_create

# Adult Regimens: RHZE (R150/H75/Z400/E275) && RH (R150/H75)
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 2, min_weight: 25, max_weight: 37, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 3, min_weight: 38, max_weight: 54, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 4, min_weight: 55, max_weight: 74, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RHZE (R150/H75/Z400/E275)'), am_dose: 5, min_weight: 75, max_weight: 1000, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 2, min_weight: 25, max_weight: 37, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 3, min_weight: 38, max_weight: 54, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 4, min_weight: 55, max_weight: 74, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'RH (R150/H75)'), am_dose: 5, min_weight: 75, max_weight: 1000, creator: 1).first_or_create

# side effects drugs
NtpRegimen.where(drug: Drug.find_by(name: 'S (Streptomycin 0.50mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'S (Streptomycin 0.75mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'S (Streptomycin 1.00mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (25mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (50mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (150mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create

NtpRegimen.where(drug: Drug.find_by(name: 'Rifabutin (150mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
