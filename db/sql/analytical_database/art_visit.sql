

with attribute_concepts as  
(
select 'cd4_count' as attribute,'5497' as attribute_concepts union all
select 'patient_present' as attribute,'1805' as attribute_concepts union all
select 'guardian_present' as attribute,'2122' as attribute_concepts union all
select 'visit_type' as attribute,'5315' as attribute_concepts union all
select 'weight' as attribute,'5089' as attribute_concepts union all
select 'height' as attribute,'5090' as attribute_concepts union all
select 'bmi' as attribute,'2137' as attribute_concepts union all
select 'systolic_blood_pressure' as attribute,'5085' as attribute_concepts union all
select 'diastolic_blood_pressure' as attribute,'5086' as attribute_concepts union all
select 'temperature' as attribute,'5088' as attribute_concepts union all
select 'blood_oxygen_saturation' as attribute,'5092' as attribute_concepts union all
select 'pulse' as attribute,'5087' as attribute_concepts union all
select 'patient_pregnant' as attribute,'1755,6131' as attribute_concepts union all
select 'patient_breastfeeding' as attribute,'834,7965' as attribute_concepts union all
select 'family_planning_method_currently_on' as attribute,'374' as attribute_concepts union all
select 'family_planning_method_provided_today' as attribute,'374' as attribute_concepts union all
select 'reason_for_not_using_family_planning_method' as attribute,'6195' as attribute_concepts union all
select 'side_effects' as attribute,'5945,512,9440,2148,877,6029,3,107,215,219,620,821,867,1458,5978,5980,6408,8260,9242' as attribute_concepts union all
select 'tb_status' as attribute,'7459' as attribute_concepts union all
select 'date_started_treatment_known' as attribute,'1421' as attribute_concepts union all
select 'date_started_treatment' as attribute,'1421' as attribute_concepts union all
select 'routine_tb_screening' as attribute,'8259' as attribute_concepts union all
select 'doses_missed' as attribute,'2973' as attribute_concepts union all
select 'art_adherence' as attribute,'818,2681' as attribute_concepts union all
select 'reason_for_poor_adherence' as attribute,'1740,2686,3140' as attribute_concepts union all
select 'lab_test_type' as attribute,'9737' as attribute_concepts union all
select 'lab_reason_for_test' as attribute,'2429' as attribute_concepts union all
select 'lab_result' as attribute,'7363,2216' as attribute_concepts union all
select 'does_the_patient_have_hypertension' as attribute,'6414' as attribute_concepts union all
select 'date_hypertension_was_diagnosed' as attribute,'6415' as attribute_concepts union all
select 'htn_date_enrolled' as attribute,'8754' as attribute_concepts union all
select 'risk_factors' as attribute,'9500' as attribute_concepts union all
select 'hypertension_drugs_prescribed' as attribute,'9498' as attribute_concepts union all
select 'notes' as attribute,'5097' as attribute_concepts
),
obs_data as (
select o.person_id, 
o.concept_id,date(o.obs_datetime) visit_date,ac.`attribute`, cn.name AS concept_name, o.concept_id AS obs_concept_id,
o.value_coded, cn2.name AS value_coded_value, o.value_coded_name_id,
o.value_drug, o.value_datetime, o.value_modifier, o.value_numeric, o.value_text
from obs o JOIN    attribute_concepts ac ON  FIND_IN_SET(o.concept_id, ac.attribute_concepts) > 0 
LEFT JOIN concept_name cn ON o.concept_id = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' AND cn.locale = 'en' AND cn.voided = 0
LEFT JOIN concept_name cn2 ON o.value_coded = cn2.concept_id AND cn2.concept_name_type = 'FULLY_SPECIFIED' AND cn2.locale = 'en' AND cn2.voided = 0
),
final_pull as 
(
select distinct x.patient_id,x.visit_date,x.site_id from (
select distinct e.patient_id,date(e.encounter_datetime) visit_date,
(select property_value site_id from global_property where property='current_health_center_id') site_id
from obs o
join encounter e on o.encounter_id=e.encounter_id
join concept_name cn on cn.concept_id=o.concept_id and cn.voided=0 and cn.locale='en'
and cn.concept_name_type='FULLY_SPECIFIED'
where o.concept_id in 
(select concept_id from concept_name where name in ('HIV viral load','Amount dispensed')
and voided=0 and locale='en'
and concept_name_type='FULLY_SPECIFIED')
and o.voided=0 and o.encounter_id is not null and o.person_id  is not null
and e.voided = 0 and e.encounter_type in (54,25,57,13)
and COALESCE(o.value_text,o.value_numeric) is not null
union all 
select distinct o.person_id patient_id,date(o.obs_datetime) visit_date,
(select property_value site_id from global_property where property='current_health_center_id') site_id
from obs o
join concept_name cn on cn.concept_id=o.concept_id and cn.voided=0 and cn.locale='en'
and cn.concept_name_type='FULLY_SPECIFIED'
where o.concept_id in 
(select concept_id from concept_name where name in ('HIV viral load','Amount dispensed')
and voided=0 and locale='en'
and concept_name_type='FULLY_SPECIFIED')
and o.voided=0 and o.encounter_id is not null and o.person_id  is not null
and COALESCE(o.value_text,o.value_numeric) is not null
union all 
select distinct ob.person_id patient_id,date(o.start_date) visit_date,
(select property_value site_id from global_property where property='current_health_center_id') site_id
from orders o
join obs ob on o.order_id =ob.order_id 
join concept_name cn on cn.concept_id=ob.concept_id and cn.voided=0 and cn.locale='en' 
and cn.name in ('HIV viral load') and cn.concept_name_type='FULLY_SPECIFIED'
where ob.voided=0 and o.voided=0 
) x
),
medication_regimen AS (
    SELECT
        GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs,
        regimen_name.name AS regimen_name
    FROM moh_regimen_combination combo
    INNER JOIN moh_regimen_combination_drug drug
        ON combo.regimen_combination_id = drug.regimen_combination_id
    INNER JOIN moh_regimen_name regimen_name
        ON combo.regimen_name_id = regimen_name.regimen_name_id
    GROUP BY combo.regimen_combination_id
),
final_dispensations AS (
SELECT
    o.patient_id,
    date(o.start_date) visit_date,
    GROUP_CONCAT(DISTINCT d.drug_inventory_id ORDER BY d.drug_inventory_id ASC) AS drug_comb,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',date(o.auto_expire_date))) as auto_expire_date,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',o.instructions) SEPARATOR '|' ) as instructions,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',COALESCE(ob.value_numeric,ob.value_text,0))) as pillcount,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose))) AS equivalent_daily_dose,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',IF(d.quantity = 0, 1, d.quantity))) AS quantity,
    GROUP_CONCAT(DISTINCT concat(doo.drug_inventory_id,':',coalesce(obbb.value_numeric,obbb.value_text))) as art_pills_remaining_at_home,
    GROUP_CONCAT(DISTINCT concat(do.drug_inventory_id,':',coalesce(obb.value_numeric,obb.value_text))) as art_pills_remaining_brought_to_clinic,
    COALESCE((
        SELECT mr.regimen_name 
        FROM medication_regimen mr 
        WHERE mr.drugs = (
            SELECT GROUP_CONCAT(DISTINCT d2.drug_inventory_id ORDER BY d2.drug_inventory_id ASC)
            FROM drug_order d2
            WHERE d2.order_id IN (
                SELECT o2.order_id 
                FROM orders o2 
                WHERE o2.patient_id = o.patient_id 
                AND date(o2.start_date) = date(o.start_date)
                AND o2.voided = 0
            )
            AND d2.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
        )
    ), 'Unknown') AS art_regimen,
    1 as dispensed 
FROM orders o
JOIN drug_order d ON o.order_id = d.order_id
AND o.patient_id = @patient_id
JOIN obs ob ON ob.order_id = o.order_id AND date(o.start_date)=date(ob.obs_datetime)
JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type IN (54,25) 
LEFT JOIN obs obb ON obb.person_id = o.patient_id AND obb.concept_id=2540 AND obb.voided=0 AND date(o.start_date)=date(obb.obs_datetime) 
LEFT JOIN drug_order do ON obb.order_id=do.order_id 
LEFT JOIN obs obbb ON obbb.person_id = o.patient_id AND obbb.concept_id=6781 AND obbb.voided=0 AND date(o.start_date)=date(obbb.obs_datetime)
LEFT JOIN drug_order doo ON obbb.order_id=doo.order_id
WHERE 
   e.voided = 0 
   AND o.voided = 0
   AND d.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
   AND COALESCE(ob.value_numeric,ob.value_text,0)>0
   AND (do.drug_inventory_id IN (SELECT drug_id FROM arv_drug) OR do.drug_inventory_id IS NULL)
GROUP BY o.patient_id, o.start_date),
final_non_art_dispensations AS (
SELECT
    o.patient_id,
    date(o.start_date) visit_date,
    GROUP_CONCAT(DISTINCT d.drug_inventory_id ORDER BY d.drug_inventory_id ASC) AS drug_comb,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',date(o.auto_expire_date))) as auto_expire_date,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',o.instructions) SEPARATOR '|' ) as instructions,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',COALESCE(ob.value_numeric,ob.value_text,0))) as pillcount,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose))) AS equivalent_daily_dose,
    GROUP_CONCAT(DISTINCT concat(d.drug_inventory_id,':',IF(d.quantity = 0, 1, d.quantity))) AS quantity,
    GROUP_CONCAT(DISTINCT concat(doo.drug_inventory_id,':',coalesce(obbb.value_numeric,obbb.value_text))) as other_pills_remaining_at_home,
    GROUP_CONCAT(DISTINCT concat(do.drug_inventory_id,':',coalesce(obb.value_numeric,obb.value_text))) as other_pills_remaining_brought_to_clinic,
    1 as dispensed 
FROM orders o
JOIN drug_order d ON o.order_id = d.order_id
AND o.patient_id = @patient_id
JOIN obs ob ON ob.order_id = o.order_id AND date(o.start_date)=date(ob.obs_datetime)
JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type IN (54,25) 
LEFT JOIN obs obb ON obb.person_id = o.patient_id AND obb.concept_id=2540 AND obb.voided=0 AND date(o.start_date)=date(obb.obs_datetime) 
LEFT JOIN drug_order do ON obb.order_id=do.order_id 
LEFT JOIN obs obbb ON obbb.person_id = o.patient_id AND obbb.concept_id=6781 AND obbb.voided=0 AND date(o.start_date)=date(obbb.obs_datetime)
LEFT JOIN drug_order doo ON obbb.order_id=doo.order_id
WHERE 
   e.voided = 0 
   AND o.voided = 0
   AND d.drug_inventory_id NOT IN (SELECT drug_id FROM arv_drug)
   AND COALESCE(ob.value_numeric,ob.value_text,0)>0
   AND (do.drug_inventory_id NOT IN (SELECT drug_id FROM arv_drug) OR do.drug_inventory_id IS NULL)
GROUP BY o.patient_id, o.start_date
),
visit_appointments as 
(
        SELECT
            o.person_id,
            pp.visit_date,
            DATE(o.value_datetime) AS appointment_date
        FROM
            obs o
        INNER JOIN (
            SELECT
                o.person_id,
                DATE(o.obs_datetime) AS visit_date,
                MAX(o.obs_id) AS obs_id
            FROM
                obs o
            WHERE
                o.concept_id IN (5096)
                AND o.voided = 0
            GROUP BY
                o.person_id,
                DATE(o.obs_datetime)
        ) pp ON pp.obs_id = o.obs_id
        AND o.person_id = @patient_id
),
art_adherence as  
(
SELECT
  o.person_id,
  date(o.obs_datetime) visit_date,
  o.order_id,
  do.drug_inventory_id,
  dr.name drug_name,
  o.value_numeric,
  o.value_text,
  o.value_modifier,
  concat(dr.name,':',coalesce(o.value_numeric,o.value_text,''),coalesce(o.value_modifier,'')) art_adherence 
  FROM obs o
join  orders oo on o.order_id=oo.order_id and o.voided=0 and oo.voided=0 
join drug_order do on oo.order_id=do.order_id
join drug dr on do.drug_inventory_id = dr.drug_id
join arv_drug ad on do.drug_inventory_id = ad.drug_id
WHERE o.concept_id =6987
AND o.person_id = @patient_id
),
lab_tests_data as
(
SELECT distinct xx.* from (
WITH
test_type_concepts AS (
    SELECT cn.concept_id, name
    FROM concept_name cn
    INNER JOIN concept cc USING (concept_id)
    WHERE cn.name = 'Test type' AND cc.retired = 0 AND cn.voided = 0
),
lab_test_result_concepts AS (
    SELECT cn.concept_id, name
    FROM concept_name cn
    INNER JOIN concept cc USING (concept_id)
    WHERE cn.name = 'Lab test result' AND cc.retired = 0 AND cn.voided = 0
),
specimen_type_concepts AS (
    SELECT concept_id, name
    FROM concept_name
    WHERE name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)',
                   'Plasma', 'Sputum', 'Cerebrospinal fluid', 'Urine', 'Unknown')
      AND voided = 0
),
lab_order_types AS (
    SELECT order_type_id
    FROM order_type
    WHERE name IN ('Lab','Test') AND retired = 0
),
reason_for_testing AS (
    SELECT DISTINCT ob.person_id, o.order_id, DATE(ob.obs_datetime) visit_date,
           COALESCE(cn.name, ob.value_text) reason_for_testing
    FROM orders o
    LEFT JOIN obs ob ON o.encounter_id = ob.encounter_id
    AND o.patient_id = @patient_id
    LEFT JOIN concept_name cn ON ob.value_coded = cn.concept_id
        AND cn.concept_name_type='FULLY_SPECIFIED' AND cn.voided=0 AND cn.locale='en'
    WHERE o.order_type_id = 4
      AND ob.concept_id IN (2429,10609,10610)
      AND ob.voided=0 AND o.voided=0
      AND COALESCE(cn.name, ob.value_text) IS NOT NULL
)
SELECT DISTINCT
    o.patient_id,
    rft.reason_for_testing AS lab_reason_for_test,
    DATE(o.start_date) AS lab_order_test_date,
    test_type.name AS lab_test_type,
    DATE(vl_obs.obs_datetime) AS lab_result_date,
    COALESCE(vl_obs.value_modifier, '=') AS result_modifier,
    COALESCE(vl_obs.value_numeric, vl_obs.value_text) AS `result`,
    CONCAT(' ', COALESCE(vl_obs.value_modifier, '='), COALESCE(vl_obs.value_numeric, vl_obs.value_text)) AS lab_result,
    '' AS results_test_facility,
    specimen_type.name AS sample_type,
    '' AS sending_facility
FROM orders  o
LEFT JOIN reason_for_testing rft
    ON rft.person_id = o.patient_id 
   AND rft.order_id = o.order_id
   AND rft.visit_date = DATE(o.start_date)
   AND o.patient_id = @patient_id
LEFT JOIN specimen_type_concepts specimen_type
    ON specimen_type.concept_id = o.concept_id
LEFT JOIN obs  test_obs
    ON test_obs.order_id = o.order_id 
    AND test_obs.concept_id IN (SELECT concept_id FROM test_type_concepts)
    AND test_obs.voided = 0
LEFT JOIN concept_name test_type
    ON test_obs.value_coded = test_type.concept_id
    AND test_type.concept_name_type='FULLY_SPECIFIED'
    AND test_type.locale = 'en' AND test_type.voided = 0
LEFT JOIN obs  vl_obs
    ON vl_obs.order_id = o.order_id 
    AND vl_obs.concept_id = 856
    AND vl_obs.voided = 0
LEFT JOIN person  p ON p.person_id = o.patient_id AND p.voided = 0 
WHERE o.order_type_id IN (SELECT order_type_id FROM lab_order_types)
  AND o.voided = 0
  AND (vl_obs.obs_id IS NOT NULL OR o.concept_id IS NOT NULL)
UNION ALL
SELECT DISTINCT
    o.person_id AS patient_id,
    coalesce(rft.reason_for_testing,NULL) AS lab_reason_for_test,
    DATE(o.obs_datetime) as lab_order_test_date,
    'Viral Load' AS lab_test_type,
    DATE(o.obs_datetime) AS lab_result_date,
    COALESCE(o.value_modifier, '=') AS result_modifier,
    COALESCE(o.value_numeric, o.value_text) AS `result`,
    CONCAT(' ', COALESCE(o.value_modifier, '='), COALESCE(o.value_numeric, o.value_text)) AS lab_result,
    '' AS results_test_facility,
    '' AS sample_type,
    '' AS sending_facility
FROM obs  o
LEFT JOIN reason_for_testing rft
    ON rft.person_id = o.person_id 
   AND rft.order_id = o.order_id
JOIN encounter  e ON o.encounter_id = e.encounter_id 
JOIN concept_name cn ON cn.concept_id = o.concept_id
    AND cn.concept_name_type='FULLY_SPECIFIED'
    AND cn.locale = 'en'
    AND cn.voided = 0
WHERE o.concept_id = 856
  AND o.voided = 0
  AND o.order_id IS NULL
  AND o.person_id IS NOT NULL
  AND COALESCE(o.value_text, o.value_numeric) IS NOT NULL AND
  COALESCE(o.value_text, o.value_numeric) !=''
  AND e.voided = 0
  AND e.encounter_type IN (57,13)
) xx where xx.`result` is null or  xx.`result` NOT IN ('<','>','=','') and xx.lab_order_test_date is not null
)
select distinct
fp.patient_id, fp.site_id,
fp.visit_date,
max(case when od.`attribute`='patient_present' then od.value_coded_value else NULL end) as patient_present,
max(case when od.`attribute`='guardian_present' then od.value_coded_value else NULL end) as guardian_present,
max(case when od.`attribute`='visit_type' then od.value_coded_value else NULL end) as visit_type,
max(case when od.`attribute`='weight' then coalesce(od.value_numeric,od.value_text) else NULL end) as weight,
max(case when od.`attribute`='height' then coalesce(od.value_numeric,od.value_text) else NULL end) as height,
max(case when od.`attribute`='bmi' then coalesce(od.value_numeric,od.value_text) else NULL end) as bmi,
max(case when od.`attribute`='systolic_blood_pressure' then coalesce(od.value_numeric,od.value_text) else NULL end) as systolic_blood_pressure,
max(case when od.`attribute`='diastolic_blood_pressure' then coalesce(od.value_numeric,od.value_text) else NULL end) as diastolic_blood_pressure,
max(case when od.`attribute`='temperature' then coalesce(od.value_numeric,od.value_text) else NULL end) as temperature,
max(case when od.`attribute`='blood_oxygen_saturation' then coalesce(od.value_numeric,od.value_text) else NULL end) as blood_oxygen_saturation,
max(case when od.`attribute`='pulse' then coalesce(od.value_numeric,od.value_text) else NULL end) as pulse,
max(case when od.`attribute`='patient_pregnant' then od.value_coded_value else NULL end) as patient_pregnant,
max(case when od.`attribute`='patient_breastfeeding' then od.value_coded_value else NULL end) as patient_breastfeeding,
max(case when od.`attribute`='family_planning_method_currently_on' then od.value_coded_value else NULL end) as family_planning_method_currently_on,
max(case when od.`attribute`='family_planning_method_provided_today' then od.value_coded_value else NULL end) as family_planning_method_provided_today,
max(case when od.`attribute`='reason_for_not_using_family_planning_method' then od.value_coded_value else NULL end) as reason_for_not_using_family_planning_method,
GROUP_CONCAT( DISTINCT IF(od.attribute = 'side_effects' AND od.value_coded_value IN ('Yes'),od.concept_name, NULL )) AS side_effects,
NULL on_tb_treatment,
max(case when od.`attribute`='tb_status' then od.value_coded_value else NULL end) as tb_status,
max(case when od.`attribute`='date_started_treatment_known' then od.value_text else NULL end) as date_started_treatment_known,
max(case when od.`attribute`='date_started_treatment' then od.value_datetime else NULL end) as date_started_treatment,
max(case when od.`attribute`='routine_tb_screening' then coalesce(od.value_coded_value,od.value_text) else NULL end) as routine_tb_screening,
max(case when od.`attribute`='cd4_count' then coalesce(od.value_coded_value,od.value_text) else NULL end) as cd4_count,
NULL allergic_to_cotrimaxole,
 case when fd.dispensed=1 then  
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) 
    else NULL end  art_treatment_dispensed,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.equivalent_daily_dose, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) AS dosage_on_art_treatment,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.auto_expire_date, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) AS art_treatment_auto_expire_date,
     (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.instructions, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ' || '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS art_treatment_instructions_given,
 fd.art_regimen regimen_category,
 case when fnd.dispensed=1 then  
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) 
    else NULL end  other_drugs_dispensed,
     (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.equivalent_daily_dose, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS dosage_on_non_art_treatment,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.auto_expire_date, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_drugs_auto_expire_date,
    (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.instructions, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ' || '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_drugs_instructions_given,
va.appointment_date next_appointment_date,
(
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.art_pills_remaining_brought_to_clinic, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS art_pills_remaining_brought_to_clinic,
  (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fd.art_pills_remaining_at_home, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS art_pills_remaining_at_home,
(
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.other_pills_remaining_brought_to_clinic, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_pills_remaining_brought_to_clinic,
  (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnd.other_pills_remaining_at_home, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnd.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_pills_remaining_at_home,
max(case when od.`attribute`='doses_missed' then od.value_numeric else NULL end) as doses_missed,
group_concat( distinct aa.art_adherence)   art_adherence,
max(case when od.`attribute`='reason_for_poor_adherence' then coalesce(od.value_coded_value,od.value_text) else NULL end) as reason_for_poor_adherence,
ltd.lab_order_test_date,
group_concat( distinct case when ltd.lab_test_type is not null and ltd.lab_test_type !='' then ltd.lab_test_type else null end )  lab_test_type,
group_concat(distinct ltd.lab_reason_for_test)  lab_reason_for_test,
TRIM(LEADING ',' FROM GROUP_CONCAT(DISTINCT CASE WHEN ltd.lab_result_date IS NOT NULL THEN ltd.lab_result_date  ELSE NULL END)) AS lab_result_date,
group_concat( distinct concat(ltd.lab_result_date,':',ltd.lab_result)) lab_result,
group_concat( distinct case when ltd.sample_type is not null and ltd.sample_type !='' then ltd.sample_type else null end ) sample_type
from 
final_pull fp left join
obs_data od on (fp.patient_id,fp.visit_date)=(od.person_id,od.visit_date)
left join final_dispensations fd on (fp.patient_id,fp.visit_date)=(fd.patient_id,fd.visit_date)
left join final_non_art_dispensations fnd on (fp.patient_id,fp.visit_date)=(fnd.patient_id,fnd.visit_date)
left join visit_appointments va on (fp.patient_id,fp.visit_date)=(va.person_id,va.visit_date)
left join art_adherence aa on (fp.patient_id,fp.visit_date)=(aa.person_id,aa.visit_date)
left join lab_tests_data ltd ON fp.patient_id=ltd.patient_id and date(fp.visit_date)=date(ltd.lab_order_test_date)
WHERE fp.patient_id = @patient_id
AND fp.visit_date = '@visit_date'
group by fp.patient_id,fp.visit_date;