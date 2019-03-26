UPDATE obs SET value_numeric = value_text
WHERE concept_id IN (SELECT concept_id FROM concept_name
                     WHERE name IN ('Weight', 'Height (cm)'))
  AND value_numeric IS NULL
  AND value_text IS NOT NULL;