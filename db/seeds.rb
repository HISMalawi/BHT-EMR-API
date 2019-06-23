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

# Isoniazid
Drug.where(concept_id: 656, name: 'Isoniazid (150mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 656, name: 'Isoniazid (200mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 656, name: 'Isoniazid (300mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Rifampicin
Drug.where(concept_id: 767, name: 'Rifampicin (300mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 767, name: 'Rifampicin (450mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 767, name: 'Rifampicin (600mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Pyrazinamide
Drug.where(concept_id: 5829, name: 'Pyrazinamide (800mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 5829, name: 'Pyrazinamide (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 5829, name: 'Pyrazinamide (1200mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 5829, name: 'Pyrazinamide (1600mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 5829, name: 'Pyrazinamide (2000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Ethambutol
Drug.where(concept_id: 745, name: 'Ethambutol (600mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 745, name: 'Ethambutol (800mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 745, name: 'Ethambutol (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 745, name: 'Ethambutol (1200mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Rifabutin
Drug.where(concept_id: 2460, name: 'Rifabutin (300mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# 1414 | Ethionamide
Drug.where(concept_id: 1414, name: 'Ethionamide (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1414, name: 'Ethionamide (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1414, name: 'Ethionamide (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Prothionamide
Drug.where(concept_id: 1415, name: 'Prothionamide (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1415, name: 'Prothionamide (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1415, name: 'Prothionamide (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Cycloserine
Drug.where(concept_id: 1413, name: 'Cycloserine (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1413, name: 'Cycloserine (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# P-aminosalicylic acid
Drug.where(concept_id: 1419, name: 'P-aminosalicylic acid (8g)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'g', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1419, name: 'P-aminosalicylic acid (8-12g)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'g', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Clofazimine
Drug.where(concept_id: 1412, name: 'Clofazimine (200mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'g', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1412, name: 'Clofazimine (300mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'g', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1412, name: 'Clofazimine (100mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'g', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Streptomycin
Drug.where(concept_id: 438, name: 'Streptomycin (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'Streptomycin (600mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'Streptomycin (700mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'Streptomycin (800mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'Streptomycin (900mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 438, name: 'Streptomycin (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Kanamycin
Drug.where(concept_id: 1417, name: 'Kanamycin (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Kanamycin (625mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Kanamycin (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Kanamycin (875mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Kanamycin (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Amikacin
Drug.where(concept_id: 1417, name: 'Amikacin (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Amikacin (625mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Amikacin (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Amikacin (875mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1417, name: 'Amikacin (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Capreomycin
Drug.where(concept_id: 1411, name: 'Capreomycin (500mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1411, name: 'Capreomycin (600mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1411, name: 'Capreomycin (750mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1411, name: 'Capreomycin (800mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 1411, name: 'Capreomycin (1000mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# Pyridoxine
Drug.where(concept_id: 766, name: 'Pyridoxine (25mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 766, name: 'Pyridoxine (50mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create
Drug.where(concept_id: 766, name: 'Pyridoxine (150mg)', combination: 1, dosage_form: 4020, route: 3327, dose_strength: 1, units: 'mg', creator: 1, uuid: SecureRandom.uuid).first_or_create

# TO add: Levofloxacillin, Moxifloxacillin, Badaquiline, Delamanid, Linezolid

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

# DR-TB drugs for patients 30 kg and above
# Isoniazid
NtpRegimen.where(drug: Drug.find_by(name: 'Isoniazid (150mg)'), am_dose: 1, min_weight: 30, max_weight: 35, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Isoniazid (200mg)'), am_dose: 1, min_weight: 36, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Isoniazid (300mg)'), am_dose: 1, min_weight: 46, max_weight: 1000, creator: 1).first_or_create

# Rifampicin
NtpRegimen.where(drug: Drug.find_by(name: 'Rifampicin (300mg)'), am_dose: 1, min_weight: 30, max_weight: 35, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Rifampicin (450mg)'), am_dose: 1, min_weight: 36, max_weight: 55, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Rifampicin (600mg)'), am_dose: 1, min_weight: 56, max_weight: 1000, creator: 1).first_or_create

# Pyrazinamide
NtpRegimen.where(drug: Drug.find_by(name: 'Pyrazinamide (800mg)'), am_dose: 1, min_weight: 30, max_weight: 35, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyrazinamide (1000mg)'), am_dose: 1, min_weight: 36, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyrazinamide (1200mg)'), am_dose: 1, min_weight: 46, max_weight: 55, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyrazinamide (1600mg)'), am_dose: 1, min_weight: 56, max_weight: 70, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyrazinamide (2000mg)'), am_dose: 1, min_weight: 71, max_weight: 1000, creator: 1).first_or_create

# Ethambutol
NtpRegimen.where(drug: Drug.find_by(name: 'Ethambutol (600mg)'), am_dose: 1, min_weight: 30, max_weight: 35, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Ethambutol (800mg)'), am_dose: 1, min_weight: 36, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Ethambutol (1000mg)'), am_dose: 1, min_weight: 46, max_weight: 55, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Ethambutol (1200mg)'), am_dose: 1, min_weight: 56, max_weight: 1000, creator: 1).first_or_create

# Rifabutin
NtpRegimen.where(drug: Drug.find_by(name: 'Rifabutin (300mg)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create

# Ethionamide
NtpRegimen.where(drug: Drug.find_by(name: 'Ethionamide (500mg)'), am_dose: 1, pm_dose: 1, min_weight: 30, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Ethionamide (750mg)'), am_dose: 1, pm_dose: 1, min_weight: 46, max_weight: 70, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Ethionamide (1000mg)'), am_dose: 1, pm_dose: 1, min_weight: 71, max_weight: 1000, creator: 1).first_or_create

# Prothionamide
NtpRegimen.where(drug: Drug.find_by(name: 'Prothionamide (500mg)'), am_dose: 1, pm_dose: 1, min_weight: 30, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Prothionamide (750mg)'), am_dose: 1, pm_dose: 1, min_weight: 46, max_weight: 70, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Prothionamide (1000mg)'), am_dose: 1, pm_dose: 1, min_weight: 71, max_weight: 1000, creator: 1).first_or_create

# Cycloserine
NtpRegimen.where(drug: Drug.find_by(name: 'Cycloserine (500mg)'), am_dose: 1, pm_dose: 1, min_weight: 30, max_weight: 55, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Cycloserine (750mg)'), am_dose: 1, pm_dose: 1, min_weight: 56, max_weight: 1000, creator: 1).first_or_create

# P-aminosalicylic acid
NtpRegimen.where(drug: Drug.find_by(name: 'P-aminosalicylic acid (8g)'), am_dose: 1, pm_dose: 1, min_weight: 30, max_weight: 70, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'P-aminosalicylic acid (8-12g)'), am_dose: 1, pm_dose: 1, min_weight: 71, max_weight: 1000, creator: 1).first_or_create

# Clofazimine
NtpRegimen.where(drug: Drug.find_by(name: 'Clofazimine (200mg)'), am_dose: 1, min_weight: 30, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Clofazimine (300mg)'), am_dose: 1, min_weight: 30, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Clofazimine (100mg)'), am_dose: 1, min_weight: 30, max_weight: 1000, creator: 1).first_or_create

# Streptomycin
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (500mg)'), am_dose: 1, min_weight: 30, max_weight: 33, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (600mg)'), am_dose: 1, min_weight: 34, max_weight: 40, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (700mg)'), am_dose: 1, min_weight: 41, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (800mg)'), am_dose: 1, min_weight: 46, max_weight: 50, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (900mg)'), am_dose: 1, min_weight: 51, max_weight: 70, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Streptomycin (1000mg)'), am_dose: 1, min_weight: 71, max_weight: 1000, creator: 1).first_or_create

# Kanamycin
NtpRegimen.where(drug: Drug.find_by(name: 'Kanamycin (500mg)'), am_dose: 1, min_weight: 30, max_weight: 33, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Kanamycin (625mg)'), am_dose: 1, min_weight: 34, max_weight: 40, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Kanamycin (750mg)'), am_dose: 1, min_weight: 41, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Kanamycin (875mg)'), am_dose: 1, min_weight: 46, max_weight: 50, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Kanamycin (1000mg)'), am_dose: 1, min_weight: 51, max_weight: 1000, creator: 1).first_or_create

# Amikacin
NtpRegimen.where(drug: Drug.find_by(name: 'Amikacin (500mg)'), am_dose: 1, min_weight: 30, max_weight: 33, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Amikacin (625mg)'), am_dose: 1, min_weight: 34, max_weight: 40, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Amikacin (750mg)'), am_dose: 1, min_weight: 41, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Amikacin (875mg)'), am_dose: 1, min_weight: 46, max_weight: 50, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Amikacin (1000mg)'), am_dose: 1, min_weight: 51, max_weight: 1000, creator: 1).first_or_create

# Capreomycin
NtpRegimen.where(drug: Drug.find_by(name: 'Capreomycin (500mg)'), am_dose: 1, min_weight: 30, max_weight: 33, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Capreomycin (600mg)'), am_dose: 1, min_weight: 34, max_weight: 40, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Capreomycin (750mg)'), am_dose: 1, min_weight: 41, max_weight: 45, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Capreomycin (800mg)'), am_dose: 1, min_weight: 46, max_weight: 50, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Capreomycin (1000mg)'), am_dose: 1, min_weight: 51, max_weight: 1000, creator: 1).first_or_create

# Pyridoxine
NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (25mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (50mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create
NtpRegimen.where(drug: Drug.find_by(name: 'Pyridoxine (150mgs)'), am_dose: 1, min_weight: 0, max_weight: 1000, creator: 1).first_or_create

# Temporarily usage | TO DO - should be added by Concept Server
# intensive phase
# RHZ (R75/H50/Z150) - Child
ConceptSet.where(concept_id: ConceptName.find_by(name: 'Rifampicin isoniazid and pyrazinamide').concept_id, concept_set: ConceptName.find_by(name: 'First-line tuberculosis drugs').concept_id, sort_weight: 1, creator: 1, date_created: Time.now, uuid: SecureRandom.uuid).first_or_create
# RHZE (R150/H75/Z400/E275) - Adult
ConceptSet.where(concept_id: ConceptName.find_by(name: 'Rifampicin Isoniazid Pyrazinamide Ethambutol').concept_id, concept_set: ConceptName.find_by(name: 'First-line tuberculosis drugs').concept_id, sort_weight: 1, creator: 1, date_created: Time.now, uuid: SecureRandom.uuid).first_or_create

# Continous phase - Child and Adult
ConceptSet.where(concept_id: ConceptName.find_by(name: 'Rifampicin and isoniazid').concept_id, concept_set: ConceptName.find_by(name: 'First-line tuberculosis drugs').concept_id, sort_weight: 1, creator: 1, date_created: Time.now, uuid: SecureRandom.uuid).first_or_create

