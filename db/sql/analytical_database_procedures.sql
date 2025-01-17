DELIMITER $$

DROP PROCEDURE IF EXISTS ids_clinic_visits;
CREATE PROCEDURE ids_clinic_visits(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    SELECT e.encounter_type           AS clinical_interaction_type,
           e.encounter_id             AS visit_id,
           e.program_id,
           e.patient_id,
           input_site_id              AS site_id,
           DATE(e.encounter_datetime) AS visit_date,
           e.date_created,
           e.voided                   AS is_voided,
           e.date_voided              AS when_voided
    FROM encounter e
    WHERE e.voided = 0
      AND e.patient_id = input_patient_id
      AND DATE(e.encounter_datetime) = input_date;
END$$

DROP PROCEDURE  IF EXISTS ids_appointments;
CREATE PROCEDURE ids_appointments(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    SELECT ob.person_id                                       AS patient_id,
           input_site_id                                      AS site_id,
           ob.encounter_id                                       visit_identifier,
           COALESCE(ob.value_datetime, '1900-01-01 00:00:00') AS appointment_date,
           ob.date_created,
           ob.voided                                             is_voided,
           DATE(ob.date_voided)                               AS when_voided,
           ob.concept_id                                         concept_identifier,
           cn.name                                            AS concept_label
    FROM obs ob
             JOIN encounter en ON ob.encounter_id = en.encounter_id
             JOIN concept_name cn ON ob.concept_id = cn.concept_id
    WHERE en.encounter_type = 7 # Appointment encounter
      AND ob.person_id = input_patient_id
      AND DATE(en.encounter_datetime) = input_date
    GROUP BY ob.encounter_id, ob.concept_id, ob.person_id, site_id, appointment_date, ob.date_created, is_voided
           , when_voided
           , cn.name;

end $$

DROP PROCEDURE IF EXISTS  ids_family_plannings;
CREATE PROCEDURE ids_family_plannings(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    SELECT ob.person_id    AS patient_id,
           input_site_id   AS site_id,
           ob.encounter_id AS visit_identifier,
           ob.concept_id   AS concept_identifier,
           cn.name         AS concept_label,
           ob.value_coded  AS coded_value,
           cn2.name        AS value,
           ob.voided       AS is_voided,
           ob.date_voided  AS when_voided
    FROM obs ob
             JOIN person p ON ob.person_id = p.person_id
             JOIN concept_name cn ON ob.concept_id = cn.concept_id
             LEFT JOIN concept_name cn2 ON ob.value_coded = cn2.concept_id
    WHERE cn.name LIKE '%family%'
      AND ob.person_id = input_patient_id
      AND DATE(ob.obs_datetime) = input_date
      AND p.gender IS NOT NULL;
end $$

DROP PROCEDURE IF EXISTS  ids_hiv_reception;
CREATE PROCEDURE ids_hiv_reception(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select x.patient_id,
           x.encounter_id AS visit_identifier,
           x.obs_id       AS observation_identifier,
           x.program_id,
           x.visit_date,
           x.patient_present,
           x.guardian_present,
           x.voided       AS is_voided,
           x.date_voided  AS when_voided,
           x.site_id
    from (WITH reception_data AS
                   (SELECT e.patient_id,
                           e.encounter_id,
                           o.obs_id,
                           e.program_id,
                           e.encounter_datetime,
                           cn.concept_id,
                           cn.name      AS concept_name,
                           o.concept_id AS obs_concept_id,
                           o.value_coded,
                           cn2.name     AS value_coded_value,
                           o.value_coded_name_id,
                           o.value_drug,
                           o.value_datetime,
                           o.value_modifier,
                           o.value_numeric,
                           o.value_text,
                           e.voided,
                           e.date_voided
                    FROM encounter e
                             JOIN obs o ON e.encounter_id = o.encounter_id
                        AND e.patient_id = input_patient_id
                        and DATE(encounter_datetime) = input_date
                             LEFT JOIN concept_name cn ON o.concept_id = cn.concept_id
                             LEFT JOIN concept_name cn2 ON o.value_coded = cn2.concept_id
                    WHERE e.encounter_type = 51)
          SELECT rd.patient_id,
                 rd.encounter_id,
                 rd.obs_id,
                 rd.program_id,
                 DATE(rd.encounter_datetime)                                  visit_date,
                 case when rd.concept_id = 1805 then rd.value_coded_value end patient_present,
                 rd1.value_coded_value                                        guardian_present,
                 rd.voided,
                 rd.date_voided,
                 input_site_id as                                             site_id
          from reception_data rd
                   LEFT JOIN reception_data rd1
                             ON rd.patient_id = rd1.patient_id AND rd.encounter_id = rd1.encounter_id AND
                                rd1.concept_id = 2122
          group by rd.patient_id, rd.encounter_id,  rd.obs_id,
                 rd.program_id, DATE(rd.encounter_datetime), rd.value_coded_value, rd1.value_coded_value, rd.voided, rd.date_voided) x;
end $$

DROP PROCEDURE IF EXISTS  ids_hypertension_management;
CREATE PROCEDURE ids_hypertension_management(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select e.patient_id,
           e.encounter_id AS visit_identifier,
           o.obs_id       AS observation_identifier,
           e.program_id,
           e.encounter_datetime,
           o.concept_id   AS concept_identifier,
           cn.name           concept_label,
           o.order_id        transaction_identifier,
           o.value_modifier  adjustment_factor,
           o.value_numeric   numeric_value,
           o.value_coded     coded_value,
           o.value_text      text_value,
           o.value_datetime  date_value,
           input_site_id  as site_id,
           e.voided          is_voided,
           e.date_voided     when_voided
    from encounter e
             join obs o on e.encounter_id = o.encounter_id
             LEFT JOIN concept_name cn ON o.concept_id = cn.concept_id
    where e.encounter_type = 48
      and patient_id = input_patient_id
      and DATE(encounter_datetime) = input_date;
end $$

DROP PROCEDURE IF EXISTS  ids_identifiers;
CREATE PROCEDURE ids_identifiers(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select patient_id    as person_id,
           input_site_id as site_id,
           identifier,
           identifier_type,
           voided        as is_voided,
           date_voided   as when_voided
    from patient_identifier pi2
    where pi2.patient_id = input_patient_id;
end $$

DROP PROCEDURE IF EXISTS  ids_initial_clinical_registration;
CREATE PROCEDURE ids_initial_clinical_registration(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select patient_id,
           encounter_id AS visit_identifier,
           obs_id       AS observation_identifier,
           program_id,
           follow_up_agreement,
           ever_received_art,
           confirmatory_test_type,
           confirmatory_test_location,
           confirmatory_test_date,
           date_art_last_taken,
           taken_arvs_last_2_weeks,
           taken_arvs_last_2_months,
           ever_registered_at_art_clinic,
           location_of_art_initiation,
           art_start_date,
           start_date_estimated,
           date_enrolled_at_facility,
           age_at_initiation,
           age_in_days_at_initiation,
           art_number_at_previous_location,
           hts_linkage_number,
           has_transfer_letter,
           cd4_count,
           site_id
    from (WITH registration_data AS
                   (SELECT e.patient_id,
                           e.encounter_id,
                           o.obs_id,
                           e.program_id,
                           e.encounter_datetime,
                           cn.concept_id,
                           cn.name      AS concept_name,
                           o.concept_id AS obs_concept_id,
                           o.value_coded,
                           cn2.name     AS value_coded_value,
                           o.value_coded_name_id,
                           o.value_drug,
                           o.value_datetime,
                           o.value_modifier,
                           o.value_numeric,
                           o.value_text
                    FROM encounter e
                             JOIN obs o ON e.encounter_id = o.encounter_id
                             LEFT JOIN concept_name cn ON o.concept_id = cn.concept_id
                             LEFT JOIN concept_name cn2 ON o.value_coded = cn2.concept_id
                    WHERE e.encounter_type = 9
                      AND e.patient_id = 1260
                      AND DATE(e.encounter_datetime) = '2025-01-16'),
               init_data AS
                   (SELECT p.patient_id,
                           CAST(patient_date_enrolled(p.patient_id) AS DATE)             AS date_enrolled,
                           date_antiretrovirals_started(p.patient_id, MIN(s.start_date)) AS earliest_start_date,
                           TIMESTAMPDIFF(YEAR, pe.birthdate, MIN(s.start_date))          AS age_at_initiation,
                           TIMESTAMPDIFF(DAY, pe.birthdate, MIN(s.start_date))           AS age_in_days_at_initiation
                    FROM patient_program p
                             LEFT JOIN person pe ON pe.person_id = p.patient_id
                             LEFT JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                    WHERE p.program_id = 1
                      AND p.patient_id = 1260
                      AND DATE(s.start_date) >= '1900-01-01'
                      AND date_enrolled IS NOT NULL
                    GROUP BY p.patient_id)
          SELECT rd.patient_id,
                 rd.encounter_id,
                 rd.obs_id,
                 rd.program_id,
                 IF(rd.concept_id = 2552, rd.value_coded_value, '') AS follow_up_agreement,
                 rd1.value_coded_value                              AS ever_received_art,
                 rd2.value_coded_value                              AS confirmatory_test_type,
                 rd3.value_text                                     AS confirmatory_test_location,
                 CAST(rd4.value_datetime AS DATE)                   AS confirmatory_test_date,
                 CAST(rd5.value_datetime AS DATE)                   AS date_art_last_taken,
                 rd6.value_coded_value                              AS taken_arvs_last_2_weeks,
                 rd7.value_coded_value                              AS taken_arvs_last_2_months,
                 rd8.value_coded_value                              AS ever_registered_at_art_clinic,
                 rd9.value_text                                     AS location_of_art_initiation,
                 CAST(rd10.value_datetime AS DATE)                  AS art_start_date,
                 id.earliest_start_date                                                  start_date_estimated,
                 id.date_enrolled                                                        date_enrolled_at_facility,
                 id.age_at_initiation,
                 id.age_in_days_at_initiation,
                 rd11.value_text                                                         art_number_at_previous_location,
                 rd12.value_text                                                         hts_linkage_number,
                 rd13.value_coded_value                                                  has_transfer_letter,
                 concat(' ', rd14.value_modifier, rd14.value_numeric)                    cd4_count,
                 input_site_id                                                           site_id
          FROM registration_data rd
                   LEFT JOIN registration_data rd1
                             ON rd.patient_id = rd1.patient_id AND rd.encounter_id = rd1.encounter_id AND
                                rd1.concept_id = 7754
                   LEFT JOIN registration_data rd2
                             ON rd.patient_id = rd2.patient_id AND rd.encounter_id = rd2.encounter_id AND
                                rd2.concept_id = 7880
                   LEFT JOIN registration_data rd3
                             ON rd.patient_id = rd3.patient_id AND rd.encounter_id = rd3.encounter_id AND
                                rd3.concept_id = 7881
                   LEFT JOIN registration_data rd4
                             ON rd.patient_id = rd4.patient_id AND rd.encounter_id = rd4.encounter_id AND
                                rd4.concept_id = 7882
                   LEFT JOIN registration_data rd5
                             ON rd.patient_id = rd5.patient_id AND rd.encounter_id = rd5.encounter_id AND
                                rd5.obs_concept_id = 7751
                   LEFT JOIN registration_data rd6
                             ON rd.patient_id = rd6.patient_id AND rd.encounter_id = rd6.encounter_id AND
                                rd6.obs_concept_id = 6394
                   LEFT JOIN registration_data rd7
                             ON rd.patient_id = rd7.patient_id AND rd.encounter_id = rd7.encounter_id AND
                                rd7.obs_concept_id = 7752
                   LEFT JOIN registration_data rd8
                             ON rd.patient_id = rd8.patient_id AND rd.encounter_id = rd8.encounter_id AND
                                rd8.obs_concept_id = 7937
                   LEFT JOIN registration_data rd9
                             ON rd.patient_id = rd9.patient_id AND rd.encounter_id = rd9.encounter_id AND
                                rd9.obs_concept_id = 7750
                   LEFT JOIN registration_data rd10
                             ON rd.patient_id = rd10.patient_id AND rd.encounter_id = rd10.encounter_id AND
                                rd10.obs_concept_id = 2516
                   LEFT JOIN registration_data rd11
                             ON rd.patient_id = rd11.patient_id AND rd.encounter_id = rd11.encounter_id AND
                                rd11.obs_concept_id = 6981
                   LEFT JOIN registration_data rd12
                             ON rd.patient_id = rd12.patient_id AND rd.encounter_id = rd12.encounter_id AND
                                rd12.obs_concept_id = 7879
                   LEFT JOIN registration_data rd13
                             ON rd.patient_id = rd13.patient_id AND rd.encounter_id = rd13.encounter_id AND
                                rd13.obs_concept_id = 6393
                   LEFT JOIN registration_data rd14
                             ON rd.patient_id = rd14.patient_id AND rd.encounter_id = rd14.encounter_id AND
                                rd14.obs_concept_id = 5497
                   LEFT JOIN init_data id on rd.patient_id = id.patient_id
          GROUP BY rd.patient_id, rd.encounter_id, rd.obs_id, rd.program_id, rd.value_coded, rd2.value_coded_value, rd.value_coded_value, rd1.value_coded_value, rd6.value_coded_value, rd7.value_coded_value, rd8.value_coded_value,  rd13.value_coded_value, rd1.value_coded, rd2.value_coded, rd3.value_text, rd4.value_datetime, rd5.value_datetime, rd6.value_coded, rd7.value_coded, rd8.value_coded, rd9.value_text, rd10.value_datetime, rd11.value_text, rd12.value_text, rd13.value_coded, rd14.value_numeric, rd14.value_modifier, id.earliest_start_date, id.date_enrolled, id.age_at_initiation, id.age_in_days_at_initiation) x;
end $$

DROP PROCEDURE  IF EXISTS ids_lab_orders;
CREATE PROCEDURE ids_lab_orders(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select e.patient_id,
           input_site_id      site_id,
           o.order_id         lab_order_id,
           o.accession_number tracking_number,
           o.start_date       order_date,
           o.encounter_id AS  visit_identifier,
           e.voided       AS  is_voided,
           e.date_voided  AS  when_voided,
           o.concept_id   AS  concept_identifier,
           ob.value_text      reason_for_testing
    from orders o
             join encounter e on o.encounter_id = e.encounter_id
             join obs ob on e.encounter_id = ob.encounter_id
    where order_type_id = 4
      and ob.concept_id in (2429, 10110)
      AND DATE(e.encounter_datetime) = input_date
      AND e.patient_id = input_patient_id
    GROUP BY o.order_id, o.accession_number, o.start_date, o.encounter_id, e.voided, e.date_voided, o.concept_id, ob.value_text;
end $$

DROP PROCEDURE  IF EXISTS ids_lab_results;
CREATE PROCEDURE ids_lab_results(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select lab_order_id,
           sending_facility AS results_test_facility,
           patient_id,
           site_id,
           '',
           test_type,
           sample_type,
           test_measure,
           test_result_date,
           test_result,
           voided           AS is_voided,
           date_voided      AS when_voided,
           sending_facility,
           test_result_id
    from (with test_types as
                   (SELECT concept_id
                         , encounter_id
                         , order_id    lab_order_id
                         , value_coded test_type
                    FROM obs
                    WHERE concept_id in (9737))
          select ob.order_id                                                              lab_order_id,
                 ob.person_id                                                             patient_id,
                 input_site_id                                                            site_id,
                 tt.test_type,
                 ''                                                                       sample_type,
                 ''                                                                       test_measure,
                 ob.obs_datetime                                                          test_result_date,
                 concat('', ob.value_modifier, coalesce(ob.value_numeric, ob.value_text)) test_result,
                 ob.voided,
                 ob.date_voided,
                 ''                                                                       sending_facility,
                 ob.obs_id                                                                test_result_id
          from obs ob
                   join test_types tt on ob.concept_id = tt.test_type and ob.order_id = tt.lab_order_id
              and ob.encounter_id = tt.encounter_id
          where ob.voided = 0
            AND DATE(ob.obs_datetime) = input_date
            AND ob.person_id = input_patient_id) x;
end $$

DROP PROCEDURE  IF EXISTS ids_medication_adherences;
CREATE PROCEDURE ids_medication_adherences(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select distinct encounter_id AS visit_identifier,
                    site_id,
                    obs_id       as observation_identifier,
                    order_id     as transaction_identifier,
                    drug_id,
                    adherence,
                    pills_brought_to_clinic,
                    pills_remaining_at_home,
                    voided       as is_voided,
                    voided_date  as when_voided,
                    patient_id
    from (with con as
                   (SELECT DISTINCT concept_id
                    FROM drug d
                    UNION
                    SELECT 2540 concept_id),
               drug_inventory as
                   (SELECT o.order_id, drug_inventory_id
                    FROM orders o
                             JOIN drug_order do ON o.order_id = do.order_id),
               pillcount as
                   (SELECT ob.order_id,
                           con.concept_id,
                           di.drug_inventory_id,
                           COALESCE(SUM(ob.value_numeric), 0) pillcount
                    FROM obs ob
                             JOIN drug_inventory di
                                  ON ob.order_id = di.order_id
                             JOIN con ON ob.concept_id = con.concept_id
                    WHERE ob.person_id = input_patient_id
                    GROUP BY ob.person_id, ob.order_id, di.drug_inventory_id, con.concept_id
                    ORDER BY order_id)
          SELECT e.encounter_id,
                 input_site_id                                                 site_id,
                 o.obs_id,
                 o.order_id,
                 p.drug_inventory_id                                           drug_id,
                 COALESCE(o.value_numeric, o.value_text)                       adherence,
                 case when p.concept_id = 2540 then p.pillcount end  pills_brought_to_clinic,
                 case when p.concept_id <> 2540 then p.pillcount end pills_remaining_at_home,
                 o.voided,
                 o.date_voided                                                 voided_date,
                 e.patient_id
          FROM obs o
                   join person p on o.person_id = p.person_id
              AND p.person_id = input_patient_id
                   left join pillcount p on o.order_id = p.order_id
                   join encounter e on o.encounter_id = e.encounter_id
          WHERE o.concept_id = 6987
            and p.gender is not null
            and encounter_datetime = input_date) x;
end $$

DROP PROCEDURE IF EXISTS  ids_medication_dispensations;
CREATE PROCEDURE ids_medication_dispensations(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    SELECT ob.person_id AS      patient_id
         , input_site_id        site_id
         , ob.obs_id            observation_identifier
         , o.order_id           transaction_identifier
         , ob.value_numeric     quantity
         , ob.voided            is_voided
         , ob.date_voided       when_voided
         , ob.encounter_id      visit_identifier
         , e.encounter_datetime date_dispensed
    FROM encounter e
             JOIN obs ob
                  ON e.encounter_id = ob.encounter_id
             JOIN orders o ON ob.order_id = o.order_id
    WHERE e.encounter_type = 54
      and e.voided = 0
      and ob.voided = 0
      and o.voided = 0
      AND DATE(e.encounter_datetime) = input_date
      AND ob.person_id = input_patient_id;
end $$

DROP PROCEDURE IF EXISTS  ids_outcomes;
CREATE PROCEDURE ids_outcomes(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select distinct pp.patient_id,
                    input_site_id  as site_id,
                    1577           as concept_identifier,
                    'Asymptomatic' as outcome_reason,
                    pp.program_id  as outcome_source,
                    ps.voided      as is_voided,
                    ps.date_voided as when_voided,
                    ps.start_date,
                    ps.end_date
    from patient_state ps
             join program_workflow_state pws
                  on
                      ps.state = pws.program_workflow_state_id
             join patient_program pp
                  on
                      ps.patient_program_id = pp.patient_program_id
    where pp.patient_id = input_patient_id
    LIMIT 1;
end $$

DROP PROCEDURE IF EXISTS  ids_vitals;
CREATE PROCEDURE ids_vitals(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select e.patient_id, e.encounter_id visit_identifier,o.obs_id observation_identifier, e.program_id, e.encounter_datetime, o.concept_id concept_identifier, cn.name concept_label,o.value_numeric numeric_value ,o.value_text text_value ,e.voided is_voided,e.date_voided when_voided,
input_site_id site_id
from encounter e
join obs o on e.encounter_id=o.encounter_id 
join concept_name cn on o.concept_id = cn.concept_id
where e.encounter_type =6
AND e.patient_id = input_patient_id
AND DATE(encounter_datetime) = input_date
GROUP BY o.concept_id, e.patient_id, e.encounter_id ,o.obs_id, e.program_id, e.encounter_datetime, o.concept_id, cn.name,o.value_numeric ,o.value_text ,e.voided,e.date_voided;

end $$

DROP PROCEDURE IF EXISTS  ids_screening;
CREATE PROCEDURE ids_screening(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select e.patient_id,
           e.encounter_id as                                  visit_identifier,
           o.obs_id       as                                  observation_identifier,
           e.program_id,
           e.encounter_datetime,
           o.concept_id   as                                  concept_identifier,
           cn.name                                            concept_label,
           o.value_coded                                      coded_value,
           COALESCE(cn2.name, o.value_datetime, o.value_text) value,
           e.voided                                           is_voided,
           e.date_voided                                      when_voided,
           input_site_id                                      site_id
    from encounter e
             inner join obs o on e.encounter_id = o.encounter_id
             join concept_name cn on o.concept_id = cn.concept_id
             left join concept_name cn2 on o.value_coded = cn2.concept_id
        AND DATE(encounter_datetime) = input_date
    WHERE e.patient_id = input_patient_id
    GROUP BY o.concept_id, e.encounter_id, o.obs_id, e.program_id, e.encounter_id, cn.name, o.value_coded, o.value_datetime, o.value_text, cn2.name, o.value_modifier, o.value_numeric, o.value_drug, e.patient_id, e.voided, e.date_voided;
end $$

DROP PROCEDURE IF EXISTS  ids_side_effects;
CREATE PROCEDURE ids_side_effects(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    SELECT distinct en.patient_id
                  , input_site_id   site_id
                  , ob.obs_id       observation_identifier
                  , ob.encounter_id visit_identifier
                  , ob.concept_id   concept_identifier
                  , ob.value_coded  coded_value
                  , ob.voided       is_voided
                  , ob.date_voided  when_voided
    FROM obs ob
             JOIN concept_name cn
                  on ob.concept_id = cn.concept_id
             JOIN encounter en
                  ON ob.encounter_id = en.encounter_id
    WHERE cn.name IN (select distinct cn.name
                      from obs o
                               inner join concept_name cn on cn.concept_id = o.value_coded
                      where o.concept_id in (7755)
                        and o.person_id = input_patient_id
                        AND DATE(en.encounter_datetime) = input_date)
      AND ob.value_coded = 1065;
end $$

DROP PROCEDURE IF EXISTS  ids_treatment;
CREATE PROCEDURE ids_treatment(
    IN input_site_id INT,
    IN input_patient_id INT,
    IN input_date DATE
)
BEGIN
    select patient_id,
           site_id,
           order_id    as transaction_identifier,
           drug_id,
           encounter_id   visit_identifier,
           start_date,
           end_date,
           instructions,
           voided         is_voided,
           voided_date as when_voided,
           pillcount,
           equivalent_daily_dose,
           quantity
    from (with con as
                   (SELECT DISTINCT concept_id
                    FROM drug d
                    UNION
                    SELECT 2540 concept_id),
               drug_inventory as
                   (SELECT o.order_id, drug_inventory_id
                    FROM orders o
                             JOIN drug_order do ON o.order_id = do.order_id),
               pillcount as
                   (SELECT ob.order_id,
                           (COALESCE(SUM(ob.value_numeric), 0) + COALESCE(SUM(ob.value_text), 0)) pillcount
                    FROM obs ob
                             JOIN drug_inventory di
                                  ON ob.order_id = di.order_id
                             JOIN con ON ob.concept_id = con.concept_id
                        AND ob.person_id = 1260
                        AND DATE(ob.obs_datetime) = input_date
                    GROUP BY ob.person_id, ob.order_id, di.drug_inventory_id
                    ORDER BY order_id)
          SELECT DISTINCT o.patient_id,
                          input_site_id                                                     site_id,
                          o.order_id,
                          d.drug_inventory_id                                               drug_id,
                          o.encounter_id,
                          o.start_date,
                          o.auto_expire_date                                                end_date,
                          o.instructions,
                          o.voided,
                          o.date_voided                                                     voided_date,
                          COALESCE(pillcount.pillcount, 0)                                  pillcount,
                          IF(LENGTH(IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose)) IS NULL, 1,
                             (IF(d.equivalent_daily_dose = 0, 1, d.equivalent_daily_dose))) equivalent_daily_dose,
                          IF(LENGTH(IF(d.quantity = 0, 1, d.quantity)) IS NULL, 1,
                             (IF(d.quantity = 0, 1, d.quantity)))                           quantity
          FROM orders o
                   JOIN drug_order d
                        ON o.order_id = d.order_id
                   LEFT JOIN pillcount
                             ON (o.order_id = pillcount.order_id)
                   JOIN encounter e on o.encounter_id = e.encounter_id
          WHERE o.order_type_id = 1
            AND o.patient_id = 1260
            AND DATE(e.encounter_datetime) = input_date
            AND d.drug_inventory_id <= 1057
            and e.voided = 0
            and o.voided = 0) x;
end $$

DELIMITER ;