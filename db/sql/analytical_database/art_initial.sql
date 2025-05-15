SELECT 
    p.person_id AS patient_id,
    (SELECT property_value FROM global_property WHERE property='current_health_center_id') AS site_id,
    MAX(IF(o.concept_id = 3289, cn2.name, NULL)) AS type_of_patient,
    MAX(IF(pi.identifier_type = 4 AND pi.voided = 0, pi.identifier, NULL)) AS arv_number,
    MAX(IF(o.concept_id = 2552, cn2.name, NULL)) AS agrees_to_follow_up,
    MAX(IF(o.concept_id = 7879, COALESCE(o.value_numeric, o.value_text), NULL)) AS has_hts_linkage_number,
    MAX(IF(o.concept_id = 7754, cn2.name, NULL)) AS ever_received_arvs,
    MAX(IF(o.concept_id = 7880, cn2.name, NULL)) AS confirmatory_hiv_test,
    MAX(IF(o.concept_id = 7881, o.value_text, NULL)) AS location_of_confirmatory_hiv_test,
    MAX(IF(o.concept_id = 7882, CAST(o.value_datetime AS DATE), NULL)) AS confirmatory_hiv_test_date,
    MAX(IF(o.concept_id = 7882, 
        CASE WHEN o.value_datetime IS NOT NULL AND o.value_text='Estimated' THEN 'Yes' 
             WHEN o.value_datetime IS NOT NULL AND o.value_text IS NULL THEN 'No' 
             ELSE '' END, 
        '')) AS confirmatory_hiv_test_date_est,
    MAX(IF(o.concept_id = 7751, CAST(o.value_datetime AS DATE), NULL)) AS last_taken_arvs_date,
    MAX(IF(o.concept_id = 7751, 
        CASE WHEN o.value_datetime IS NOT NULL AND o.value_text='Estimated' THEN 'Yes' 
             WHEN o.value_datetime IS NOT NULL AND o.value_text IS NULL THEN 'No' 
             ELSE '' END, 
        '')) AS last_taken_arvs_date_est,
    MAX(IF(o.concept_id = 7752, cn2.name, NULL)) AS taken_arvs_in_the_last_two_months,
    MAX(IF(o.concept_id = 6394, cn2.name, NULL)) AS taken_arvs_in_the_last_two_weeks,
    MAX(IF(o.concept_id = 7937, cn2.name, NULL)) AS ever_registered_at_an_art_clinic,
    MAX(IF(o.concept_id = 7750, o.value_text, NULL)) AS location_of_art_initiation,
    COALESCE(
        MAX(IF(o.concept_id = 2516, CAST(o.value_datetime AS DATE), NULL)),
        CAST(date_antiretrovirals_started(p.person_id, MIN(ps.start_date)) AS DATE)
    ) AS art_start_date,
    CASE 
        WHEN MAX(IF(o.concept_id = 2516, o.value_datetime, NULL)) IS NULL OR patient_date_enrolled(p.person_id) IS NULL THEN ''
        ELSE TIMESTAMPDIFF(MONTH, 
            DATE(MAX(IF(o.concept_id = 2516, o.value_datetime, NULL))), 
            DATE(patient_date_enrolled(p.person_id)))
    END AS months_on_art,
    TIMESTAMPDIFF(YEAR, pe.birthdate, MIN(ps.start_date)) AS age_at_initiation,
    TIMESTAMPDIFF(DAY, pe.birthdate, MIN(ps.start_date)) AS age_in_days_at_initiation,
    MAX(IF(o.concept_id = 6981, o.value_text, NULL)) AS art_number_at_previous_location,
    MAX(IF(o.concept_id = 7972, cn2.name, NULL)) AS patient_pregnant,
    MAX(IF(o.concept_id = 5632, cn2.name, NULL)) AS patient_breastfeeding,
    MAX(IF(o.concept_id = 7562, cn2.name, NULL)) AS who_stage,
    MAX(IF(o.concept_id = 7563, cn2.name, NULL)) AS reason_for_starting,
    MAX(IF(o.concept_id = 5497, CONCAT(' ', o.value_modifier, o.value_numeric), NULL)) AS cd4_count,
    CAST(patient_date_enrolled(p.person_id) AS DATE) AS date_enrolled_at_facility
FROM 
    person p
LEFT JOIN 
    patient_program pp ON p.person_id = pp.patient_id AND pp.program_id = 1 AND pp.voided = 0
LEFT JOIN 
    patient_state ps ON pp.patient_program_id = ps.patient_program_id AND ps.voided = 0 AND DATE(ps.start_date) >= '1900-01-01'
LEFT JOIN 
    encounter e ON p.person_id = e.patient_id AND e.encounter_type IN (9,5,52) AND e.voided = 0
LEFT JOIN 
    obs o ON e.encounter_id = o.encounter_id AND o.voided = 0 AND o.concept_id IN (
        7754, 7880, 7881, 7882, 7751, 6394, 7752, 7937, 7750, 2516, 
        6981, 7879, 6393, 5497, 3289, 2552, 7972, 5632, 7562, 7563
    )
LEFT JOIN 
    concept_name cn ON o.concept_id = cn.concept_id AND cn.locale = 'en' AND cn.voided = 0 AND cn.concept_name_type = 'FULLY_SPECIFIED'
LEFT JOIN 
    concept_name cn2 ON o.value_coded = cn2.concept_id AND cn2.locale = 'en' AND cn2.voided = 0 AND cn2.concept_name_type = 'FULLY_SPECIFIED'
LEFT JOIN 
    patient_identifier pi ON p.person_id = pi.patient_id AND pi.identifier_type = 4 AND pi.voided = 0
LEFT JOIN 
    person pe ON p.person_id = pe.person_id
WHERE 
    patient_date_enrolled(p.person_id) IS NOT NULL
    AND p.person_id = @patient_id
GROUP BY 
    p.person_id;
