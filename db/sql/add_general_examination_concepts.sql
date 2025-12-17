-- Migration: Add missing concepts for General Examination
-- Description: Adds concept names required for the General Examination module in Neonatal

-- ==============================================================================
-- GENITALIA CONCEPTS
-- ==============================================================================

-- Create Genitalia parent concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'Coded' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Question' LIMIT 1),
       1, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0);

-- Add Genitalia concept name
INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Genitalia', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
WHERE c.concept_id NOT IN (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
AND c.concept_id = (SELECT MAX(concept_id) FROM concept WHERE is_set = 1)
LIMIT 1;

-- Create Normal concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Misc' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Normal' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Normal', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Normal' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create Abnormal concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Misc' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Abnormal' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Abnormal', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Abnormal' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create Ambiguous concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Misc' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Ambiguous' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Ambiguous', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Ambiguous' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create Hypospadias concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Diagnosis' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Hypospadias' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Hypospadias', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Hypospadias' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create Undescended testes concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Diagnosis' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Undescended testes' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Undescended testes', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Undescended testes' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Link child concepts to Genitalia set
INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'Normal' AND voided = 0 LIMIT 1),
    1, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'Normal' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'Abnormal' AND voided = 0 LIMIT 1),
    2, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'Abnormal' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'Ambiguous' AND voided = 0 LIMIT 1),
    3, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'Ambiguous' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'Hypospadias' AND voided = 0 LIMIT 1),
    4, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'Hypospadias' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Genitalia' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'Undescended testes' AND voided = 0 LIMIT 1),
    5, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Genitalia' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'Undescended testes' AND voided = 0);

-- ==============================================================================
-- PALATE CONCEPTS (Cleft Lip & Palate)
-- ==============================================================================

-- Create Palate parent concept if it doesn't exist
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'Coded' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Question' LIMIT 1),
       1, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'Palate' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'Palate', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'Palate' AND cn.voided = 0
WHERE cn.concept_id IS NULL AND c.is_set = 1
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create normal concept
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Misc' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'normal' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'normal', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'normal' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create cleft_palate concept
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Diagnosis' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_palate' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'cleft_palate', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'cleft_palate' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create cleft_lip concept
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Diagnosis' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_lip' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'cleft_lip', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'cleft_lip' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Create cleft_lip_and_palate concept
INSERT INTO concept (retired, datatype_id, class_id, is_set, creator, date_created, uuid)
SELECT 0,
       (SELECT concept_datatype_id FROM concept_datatype WHERE name = 'N/A' LIMIT 1),
       (SELECT concept_class_id FROM concept_class WHERE name = 'Diagnosis' LIMIT 1),
       0, 1, NOW(), UUID()
WHERE NOT EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_lip_and_palate' AND voided = 0);

INSERT INTO concept_name (concept_id, name, locale, locale_preferred, creator, date_created, uuid, concept_name_type, voided)
SELECT c.concept_id, 'cleft_lip_and_palate', 'en', 1, 1, NOW(), UUID(), 'FULLY_SPECIFIED', 0
FROM concept c
LEFT JOIN concept_name cn ON c.concept_id = cn.concept_id AND cn.name = 'cleft_lip_and_palate' AND cn.voided = 0
WHERE cn.concept_id IS NULL
ORDER BY c.concept_id DESC
LIMIT 1;

-- Link child concepts to Palate set
INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Palate' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'normal' AND voided = 0 LIMIT 1),
    1, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Palate' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'normal' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Palate' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'cleft_palate' AND voided = 0 LIMIT 1),
    2, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Palate' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_palate' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Palate' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'cleft_lip' AND voided = 0 LIMIT 1),
    3, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Palate' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_lip' AND voided = 0);

INSERT IGNORE INTO concept_set (concept_id, concept_set, sort_weight, creator, date_created, uuid)
SELECT
    (SELECT concept_id FROM concept_name WHERE name = 'Palate' AND voided = 0 LIMIT 1),
    (SELECT concept_id FROM concept_name WHERE name = 'cleft_lip_and_palate' AND voided = 0 LIMIT 1),
    4, 1, NOW(), UUID()
WHERE EXISTS (SELECT 1 FROM concept_name WHERE name = 'Palate' AND voided = 0)
  AND EXISTS (SELECT 1 FROM concept_name WHERE name = 'cleft_lip_and_palate' AND voided = 0);

-- Verification
SELECT 'Migration completed successfully' as Status;
SELECT 'Genitalia Concepts' as Category, name as ConceptName FROM concept_name WHERE name IN ('Genitalia', 'Normal', 'Abnormal', 'Ambiguous', 'Hypospadias', 'Undescended testes') AND voided = 0;
SELECT 'Palate Concepts' as Category, name as ConceptName FROM concept_name WHERE name IN ('Palate', 'normal', 'cleft_palate', 'cleft_lip', 'cleft_lip_and_palate') AND voided = 0;
