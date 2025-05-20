with attribute_concepts as  
(
select 'art_pills_remaining_brought_to_clinic' as attribute,'2540' as attribute_concepts union all
select 'art_pills_remaining_at_home' as attribute,'6781' as attribute_concepts union all
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
AND o.person_id = @patient_id
AND DATE(o.obs_datetime) = @visit_date
),
temp_prescriptions AS (
    SELECT
        o.patient_id,
        o.order_id,
        d.drug_inventory_id AS drug_id,
        o.encounter_id,
        o.start_date,
        o.auto_expire_date AS end_date,
        o.instructions,
        o.voided,
        o.date_voided AS voided_date,
       (COALESCE(SUM(ob.value_numeric),0) + COALESCE(SUM(ob.value_text),0)) as pillcount,
        IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose) AS equivalent_daily_dose,
        IF(d.quantity = 0, 1, d.quantity) AS quantity
    FROM orders o
    JOIN drug_order d
        ON o.order_id = d.order_id
    LEFT JOIN obs ob
        ON ob.order_id = o.order_id
        AND ob.concept_id IN (SELECT concept_id FROM drug UNION SELECT 2540)
    JOIN encounter e
        ON o.encounter_id = e.encounter_id
    WHERE 
       o.order_type_id = 1
      AND d.drug_inventory_id <= 1057
      AND e.voided = 0 
      AND e.encounter_type=25
      AND o.voided = 0
      AND d.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
      AND o.patient_id = @patient_id
    GROUP BY o.patient_id, o.order_id, d.drug_inventory_id, o.encounter_id, o.start_date, o.auto_expire_date, o.instructions, o.voided, o.date_voided, d.equivalent_daily_dose, d.quantity
),
temp_dispensed_drugs AS (
    SELECT
        o.patient_id,
        o.order_id,
        d.drug_inventory_id AS drug_id,
        o.encounter_id,
        o.start_date,
        o.auto_expire_date AS end_date,
        o.instructions,
        o.voided,
        o.date_voided AS voided_date,
       (COALESCE(SUM(ob.value_numeric),0) + COALESCE(SUM(ob.value_text),0)) as pillcount,
        IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose) AS equivalent_daily_dose,
        IF(d.quantity = 0, 1, d.quantity) AS quantity
    FROM orders o
    JOIN drug_order d
        ON o.order_id = d.order_id
    JOIN obs ob
        ON ob.order_id = o.order_id and coalesce(ob.value_numeric,0)>0
    JOIN encounter e
        ON ob.encounter_id = e.encounter_id and e.encounter_type in (54,25)
    WHERE 
       e.voided = 0 
      AND o.voided = 0
      AND o.patient_id = @patient_id
      AND d.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
    GROUP BY o.patient_id, o.order_id, d.drug_inventory_id, o.encounter_id, o.start_date, o.auto_expire_date, o.instructions, o.voided, o.date_voided, d.equivalent_daily_dose, d.quantity
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
        tp.patient_id,
        DATE(tp.start_date) AS visit_date,
        GROUP_CONCAT(DISTINCT tp.drug_id ORDER BY tp.drug_id ASC) AS drug_comb,
        GROUP_CONCAT(DISTINCT tp.instructions ORDER BY tp.drug_id ASC) AS dosage_instructions,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',tp.equivalent_daily_dose) ORDER BY tp.drug_id ASC) AS daily_dose,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',date(tp.end_date)) ORDER BY tp.drug_id ASC) AS auto_expire_date,
        GROUP_CONCAT(DISTINCT CONCAT(tp.drug_id, ':', tp.quantity) ORDER BY tp.drug_id ASC) AS quantity,
        mr.regimen_name AS art_regimen,
        1 as dispensed 
    FROM temp_dispensed_drugs tp
    JOIN medication_regimen mr
        ON mr.drugs = (SELECT GROUP_CONCAT(DISTINCT drug_id ORDER BY drug_id ASC) FROM temp_dispensed_drugs tp2 WHERE tp2.patient_id = tp.patient_id  AND tp2.encounter_id = tp.encounter_id)
    WHERE tp.patient_id = @patient_id
    GROUP BY tp.patient_id, DATE(tp.start_date), mr.regimen_name
),
final_prescriptions AS (
    SELECT
        tp.patient_id,
        (select property_value site_id from global_property where property='current_health_center_id') site_id,
        DATE(tp.start_date) AS visit_date,
        GROUP_CONCAT(DISTINCT tp.drug_id ORDER BY tp.drug_id ASC) AS drug_comb,
        GROUP_CONCAT(DISTINCT tp.instructions ORDER BY tp.drug_id ASC) AS dosage_instructions,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',tp.equivalent_daily_dose) ORDER BY tp.drug_id ASC) AS daily_dose,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',date(tp.end_date)) ORDER BY tp.drug_id ASC) AS auto_expire_date,
        GROUP_CONCAT(DISTINCT CONCAT(tp.drug_id, ':', tp.quantity) ORDER BY tp.drug_id ASC) AS quantity,
        mr.regimen_name AS art_regimen
    FROM temp_prescriptions tp
    JOIN medication_regimen mr
        ON mr.drugs = (SELECT GROUP_CONCAT(DISTINCT drug_id ORDER BY drug_id ASC) FROM temp_prescriptions tp2 WHERE tp2.patient_id = tp.patient_id  AND tp2.encounter_id = tp.encounter_id)
     WHERE  tp.patient_id = @patient_id
        GROUP BY tp.patient_id, DATE(tp.start_date), mr.regimen_name
),
temp_non_art_prescriptions AS (
    SELECT
        o.patient_id,
        o.order_id,
        d.drug_inventory_id AS drug_id,
        o.encounter_id,
        o.start_date,
        o.auto_expire_date AS end_date,
        o.instructions,
        o.voided,
        o.date_voided AS voided_date,
       (COALESCE(SUM(ob.value_numeric),0) + COALESCE(SUM(ob.value_text),0)) as pillcount,
        IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose) AS equivalent_daily_dose,
        IF(d.quantity = 0, 1, d.quantity) AS quantity
    FROM orders o
    JOIN drug_order d
        ON o.order_id = d.order_id
    LEFT JOIN obs ob
        ON ob.order_id = o.order_id
        AND ob.concept_id IN (SELECT concept_id FROM drug UNION SELECT 2540)
    JOIN encounter e
        ON o.encounter_id = e.encounter_id
    WHERE 
       o.order_type_id = 1
      AND e.voided = 0
      AND o.voided = 0
      AND d.drug_inventory_id NOT IN (SELECT drug_id FROM arv_drug)
      AND o.patient_id = @patient_id
    GROUP BY o.patient_id, o.order_id, d.drug_inventory_id, o.encounter_id, o.start_date, o.auto_expire_date, o.instructions, o.voided, o.date_voided, d.equivalent_daily_dose, d.quantity
),
final_non_art_prescriptions AS (
    SELECT
        tp.patient_id,
        DATE(tp.start_date) AS visit_date,
        GROUP_CONCAT(DISTINCT tp.drug_id ORDER BY tp.drug_id ASC) AS drug_comb,
        GROUP_CONCAT(DISTINCT tp.instructions ORDER BY tp.drug_id ASC) AS dosage_instructions,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',tp.equivalent_daily_dose) ORDER BY tp.drug_id ASC) AS daily_dose,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',date(tp.end_date)) ORDER BY tp.drug_id ASC) AS auto_expire_date,
        GROUP_CONCAT(DISTINCT CONCAT(tp.drug_id, ':', tp.quantity) ORDER BY tp.drug_id ASC) AS quantity
    FROM temp_non_art_prescriptions tp
    WHERE tp.patient_id = @patient_id
   GROUP BY tp.patient_id, DATE(tp.start_date)
),
temp_non_art_dispensed_drugs AS (
    SELECT
        o.patient_id,
        o.order_id,
        d.drug_inventory_id AS drug_id,
        o.encounter_id,
        o.start_date,
        o.auto_expire_date AS end_date,
        o.instructions,
        o.voided,
        o.date_voided AS voided_date,
       (COALESCE(SUM(ob.value_numeric),0) + COALESCE(SUM(ob.value_text),0)) as pillcount,
        IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose) AS equivalent_daily_dose,
        IF(d.quantity = 0, 1, d.quantity) AS quantity
    FROM orders o
    JOIN drug_order d
        ON o.order_id = d.order_id
    JOIN obs ob
        ON ob.order_id = o.order_id and coalesce(ob.value_numeric,0)>0
    JOIN encounter e
        ON ob.encounter_id = e.encounter_id and e.encounter_type in (54,25)
    WHERE 
       e.voided = 0 
      AND o.voided = 0
      AND d.drug_inventory_id NOT IN (SELECT drug_id FROM arv_drug)
      AND o.patient_id = @patient_id
    GROUP BY o.patient_id, o.order_id, d.drug_inventory_id, o.encounter_id, o.start_date, o.auto_expire_date, o.instructions, o.voided, o.date_voided, d.equivalent_daily_dose, d.quantity
),
final_non_art_dispensations AS (
    SELECT
        tp.patient_id,
        DATE(tp.start_date) AS visit_date,
        GROUP_CONCAT(DISTINCT tp.drug_id ORDER BY tp.drug_id ASC) AS drug_comb,
        GROUP_CONCAT(DISTINCT tp.instructions ORDER BY tp.drug_id ASC) AS dosage_instructions,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',tp.equivalent_daily_dose) ORDER BY tp.drug_id ASC) AS daily_dose,
        GROUP_CONCAT( DISTINCT CONCAT(tp.drug_id,':',date(tp.end_date)) ORDER BY tp.drug_id ASC) AS auto_expire_date,
        GROUP_CONCAT(DISTINCT CONCAT(tp.drug_id, ':', tp.quantity) ORDER BY tp.drug_id ASC) AS quantity,
        1 as dispensed 
    FROM temp_non_art_dispensed_drugs tp
    WHERE tp.patient_id = @patient_id
    GROUP BY tp.patient_id, DATE(tp.start_date)
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
                AND o.person_id = @patient_id
            GROUP BY
                o.person_id,
                DATE(o.obs_datetime)
        ) pp ON pp.obs_id = o.obs_id
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
test_type_concepts AS (
    SELECT cn.concept_id,name
    FROM concept_name cn
    INNER JOIN concept cc USING (concept_id)
    WHERE cn.name = 'Test type' AND cc.retired = 0 AND cn.voided = 0
),
reason_for_testing as 
(
select distinct ob.person_id, o.order_id, date(ob.obs_datetime) visit_date, coalesce(cn.name, ob.value_text) reason_for_testing
from orders o left join obs ob on o.encounter_id = ob.encounter_id left join concept_name cn on ob.value_coded = cn.concept_id
and cn.concept_name_type='FULLY_SPECIFIED' and cn.voided=0 and cn.locale='en'
where o.order_type_id = 4 and  ob.concept_id in (2429,10609,10610) and ob.voided=0 and o.voided=0 and  coalesce(cn.name, ob.value_text) is not null
AND o.patient_id = @patient_id
),
lab_test_result_concepts AS (
    SELECT cn.concept_id,name
    FROM concept_name cn
    INNER JOIN concept cc USING (concept_id)
    WHERE cn.name = 'Lab test result' AND cc.retired = 0 AND cn.voided = 0
),
specimen_type_concepts AS (
    SELECT concept_id,name
    FROM concept_name
    WHERE name IN ('Blood', 'DBS (Free drop to DBS card)', 'DBS (Using capillary tube)',
    'Plasma','Sputum','Cerebrospinal fluid','Urine','Unknown')
      AND voided = 0
),
lab_order_types AS (
    SELECT order_type_id
    FROM order_type
    WHERE name in ('Lab','Test') AND retired = 0
),
lab_tests_data as
(SELECT distinct
    orders.patient_id,
    rft.reason_for_testing lab_reason_for_test,
    COALESCE(DATE(COALESCE(orders.discontinued_date, orders.start_date)), 'ND') AS lab_order_test_date,
    cn.name lab_test_type,
    COALESCE(DATE(test_results_obs.obs_datetime), 'ND') AS lab_result_date,
    COALESCE(test_result_measure_obs.value_modifier, '=') AS result_modifier,
    COALESCE(test_result_measure_obs.value_numeric, test_result_measure_obs.value_text) AS result,
    CONCAT(' ', COALESCE(test_result_measure_obs.value_modifier, '='), COALESCE(test_result_measure_obs.value_numeric, test_result_measure_obs.value_text)) AS lab_result,
    '' results_test_facility,
    specimen_type.name sample_type,
    '' sending_facility
FROM orders AS orders
INNER JOIN specimen_type_concepts AS specimen_type
    ON specimen_type.concept_id = orders.concept_id
LEFT JOIN reason_for_testing rft on rft.person_id=orders.patient_id and rft.order_id=orders.order_id
and rft.visit_date=COALESCE(DATE(COALESCE(orders.discontinued_date, orders.start_date)), 'ND')
LEFT JOIN patient_identifier AS patient_identifier
    ON patient_identifier.patient_id = orders.patient_id
    AND patient_identifier.voided = 0
INNER JOIN person AS person
    ON person.person_id = orders.patient_id
    AND person.voided = 0
INNER JOIN obs AS test_obs
    ON test_obs.order_id = orders.order_id
    AND test_obs.concept_id IN (SELECT concept_id FROM test_type_concepts)
    AND test_obs.voided = 0
INNER JOIN obs AS test_results_obs
    ON test_results_obs.obs_group_id = test_obs.obs_id
    AND test_results_obs.concept_id IN (SELECT concept_id FROM lab_test_result_concepts)
    AND test_results_obs.voided = 0
INNER JOIN concept_name cn on test_obs.value_coded=cn.concept_id and cn.concept_name_type='FULLY_SPECIFIED' and cn.voided=0 and cn.locale='en'
INNER JOIN obs AS test_result_measure_obs
    ON test_result_measure_obs.obs_group_id = test_results_obs.obs_id
    AND (test_result_measure_obs.value_numeric IS NOT NULL OR test_result_measure_obs.value_text IS NOT NULL)
    AND test_result_measure_obs.voided = 0
    AND DATE(test_result_measure_obs.obs_datetime) >= DATE(COALESCE(orders.discontinued_date, orders.start_date))
WHERE orders.order_type_id IN (SELECT order_type_id FROM lab_order_types)
  AND orders.patient_id = @patient_id
  AND orders.voided = 0)
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
max(case when od.`attribute`='reason_for_not_using_family_planning_method' then od.value_coded_value else NULL end) as reason_for_not_using_family_planning_method,
GROUP_CONCAT( DISTINCT IF(od.attribute = 'side_effects' AND od.value_coded_value IN ('Yes'),od.concept_name, NULL )) AS side_effects,
NULL on_tb_treatment,
max(case when od.`attribute`='tb_status' then od.value_coded_value else NULL end) as tb_status,
max(case when od.`attribute`='date_started_treatment_known' then od.value_text else NULL end) as date_started_treatment_known,
max(case when od.`attribute`='date_started_treatment' then od.value_datetime else NULL end) as date_started_treatment,
max(case when od.`attribute`='routine_tb_screening' then coalesce(od.value_coded_value,od.value_text) else NULL end) as routine_tb_screening,
NULL allergic_to_cotrimaxole,
(
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fp.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) AS art_treatment_prescribed,
 case when fd.dispensed=1 then  
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fp.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fp.drug_comb, ']'),
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
                    SUBSTRING_INDEX(fp.daily_dose, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) AS dosage_on_art_treatment,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fp.auto_expire_date, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN arv_drug ad ON ad.drug_id = jt2.drug_id
        JOIN drug d2 ON ad.drug_id = d2.drug_id
    ) AS art_treatment_auto_expire_date,
 fp.dosage_instructions art_treatment_instructions_given, 
 fp.art_regimen regimen_category,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnp.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_drugs_prescribed,
 case when fnd.dispensed=1 then  
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnp.quantity, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) 
    else NULL end  other_drugs_dispensed,
 (
        SELECT GROUP_CONCAT(
            CONCAT(d2.name, ':', 
                SUBSTRING_INDEX(
                    SUBSTRING_INDEX(fnp.auto_expire_date, CONCAT(d2.drug_id, ':'), -1
                ), ',', 1)
            ) 
            ORDER BY d2.drug_id SEPARATOR ', '
        )
        FROM JSON_TABLE(
            CONCAT('[', fnp.drug_comb, ']'),
            '$[*]' COLUMNS (drug_id INT PATH '$')
        ) AS jt2
        JOIN drug d2 ON d2.drug_id = jt2.drug_id
    ) AS other_drugs_auto_expire_date,
fnp.dosage_instructions other_drugs_instructions_given,
va.appointment_date next_appointment_date,
max(case when od.`attribute`='art_pills_remaining_brought_to_clinic' then od.value_numeric else NULL end) as art_pills_remaining_brought_to_clinic,
max(case when od.`attribute`='art_pills_remaining_at_home' then od.value_numeric else NULL end) as art_pills_remaining_at_home,
max(case when od.`attribute`='doses_missed' then od.value_numeric else NULL end) as doses_missed,
group_concat( distinct aa.art_adherence)   art_adherence,
max(case when od.`attribute`='reason_for_poor_adherence' then coalesce(od.value_coded_value,od.value_text) else NULL end) as reason_for_poor_adherence,
ltd.lab_order_test_date,
group_concat( distinct ltd.lab_test_type)  lab_test_type,
group_concat( distinct concat(ltd.lab_test_type,':',ltd.lab_reason_for_test))  lab_reason_for_test,
group_concat( distinct concat(ltd.lab_test_type,':',ltd.lab_result_date)) lab_result_date,
group_concat( distinct concat(ltd.lab_test_type,':',ltd.lab_result)) lab_result,
group_concat( distinct concat(ltd.lab_test_type,':',ltd.sample_type)) sample_type
from 
final_prescriptions fp left join
obs_data od on (fp.patient_id,fp.visit_date)=(od.person_id,od.visit_date)
left join final_dispensations fd on (fp.patient_id,fp.visit_date)=(fd.patient_id,fd.visit_date)
left join final_non_art_prescriptions fnp on (fp.patient_id,fp.visit_date)=(fnp.patient_id,fnp.visit_date)
left join final_non_art_dispensations fnd on (fp.patient_id,fp.visit_date)=(fnd.patient_id,fnd.visit_date)
left join visit_appointments va on (fp.patient_id,fp.visit_date)=(va.person_id,va.visit_date)
left join art_adherence aa on (fp.patient_id,fp.visit_date)=(aa.person_id,aa.visit_date)
left join lab_tests_data ltd on (fp.patient_id,fp.visit_date)=(ltd.patient_id,ltd.lab_order_test_date)
WHERE fp.patient_id = @patient_id AND fp.visit_date = '@visit_date'
group by fp.patient_id,fp.visit_date;
