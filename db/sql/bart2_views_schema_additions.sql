
-- Host: localhost    Database: bart2
-- ------------------------------------------------------
-- Server version	5.1.54-1ubuntu4-log
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

/* NOTE: It was noted that some databases have all VIEWs replaced by TABLES. This
 * script fails to load on those databases because of that. Can't replace tables
 * with views. Therefore, we preceed all CREATE VIEW statements with drop table
 * statements to force our way through the damn databases.
 */

-- view to capture avg ART/HIV care treatment time for ART patients at a given site
DROP TABLE IF EXISTS `patient_service_waiting_time`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `patient_service_waiting_time` AS
    SELECT
        `e`.`patient_id` AS `patient_id`,
        cast(`e`.`encounter_datetime` as date) AS `visit_date`,
        min(`e`.`encounter_datetime`) AS `start_time`,
        max(`e`.`encounter_datetime`) AS `finish_time`,
        timediff(max(`e`.`encounter_datetime`),
                min(`e`.`encounter_datetime`)) AS `service_time`
    FROM
        (`encounter` `e`
        join `encounter` `e2` ON (((`e`.`patient_id` = `e2`.`patient_id`)
            AND (`e`.`encounter_type` in (7 , 9, 12, 25, 51, 52, 53, 54, 68)))))
    WHERE
        ((`e`.`encounter_datetime` BETWEEN date_format((now() - interval 7 day),
                '%Y-%m-%d 00:00:00') AND date_format((now() - interval 1 day),
                '%Y-%m-%d 23:59:59'))
            AND (right(`e`.`encounter_datetime`, 2) <> '01')
            AND (right(`e`.`encounter_datetime`, 2) <> '01'))
    GROUP BY `e`.`patient_id` , cast(`e`.`encounter_datetime` as date)
    ORDER BY `e`.`patient_id` , `e`.`encounter_datetime`;

-- Non-voided HIV Clinic Consultation encounters
DROP TABLE IF EXISTS `clinic_consultation_encounter`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `clinic_consultation_encounter` AS
  SELECT `encounter`.`encounter_id` AS `encounter_id`,
         `encounter`.`encounter_type` AS `encounter_type`,
         `encounter`.`patient_id` AS `patient_id`,
         `encounter`.`provider_id` AS `provider_id`,
         `encounter`.`location_id` AS `location_id`,
         `encounter`.`form_id` AS `form_id`,
         `encounter`.`encounter_datetime` AS `encounter_datetime`,
         `encounter`.`creator` AS `creator`,
         `encounter`.`date_created` AS `date_created`,
         `encounter`.`voided` AS `voided`,
         `encounter`.`voided_by` AS `voided_by`,
         `encounter`.`date_voided` AS `date_voided`,
         `encounter`.`void_reason` AS `void_reason`,
         `encounter`.`uuid` AS `uuid`,
         `encounter`.`changed_by` AS `changed_by`,
         `encounter`.`date_changed` AS `date_changed`
  FROM `encounter`
  WHERE (`encounter`.`encounter_type` = 53 AND `encounter`.`voided` = 0);

-- ARV drugs
DROP TABLE IF EXISTS `arv_drug`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `arv_drug` AS
	SELECT `drug_id` FROM `drug`
	WHERE `concept_id` IN (SELECT `concept_id` FROM `concept_set` WHERE `concept_set` = 1085);

-- ARV drugs orders
DROP TABLE IF EXISTS `arv_drugs_orders`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
   VIEW `arv_drugs_orders` AS
   SELECT `ord`.`patient_id`, `ord`.`encounter_id`, `ord`.`concept_id`, `ord`.`start_date`
   FROM `orders` `ord`
   WHERE `ord`.`voided` = 0
   AND `ord`.`concept_id` IN (SELECT `concept_id` FROM `concept_set` WHERE `concept_set` = 1085);

-- Non-voided HIV Clinic Registration encounters
DROP TABLE IF EXISTS `clinic_registration_encounter`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `clinic_registration_encounter` AS
	SELECT `encounter`.`encounter_id` AS `encounter_id`,
         `encounter`.`encounter_type` AS `encounter_type`,
         `encounter`.`patient_id` AS `patient_id`,
         `encounter`.`provider_id` AS `provider_id`,
         `encounter`.`location_id` AS `location_id`,
         `encounter`.`form_id` AS `form_id`,
         `encounter`.`encounter_datetime` AS `encounter_datetime`,
         `encounter`.`creator` AS `creator`,
         `encounter`.`date_created` AS `date_created`,
         `encounter`.`voided` AS `voided`,
         `encounter`.`voided_by` AS `voided_by`,
         `encounter`.`date_voided` AS `date_voided`,
         `encounter`.`void_reason` AS `void_reason`,
         `encounter`.`uuid` AS `uuid`,
         `encounter`.`changed_by` AS `changed_by`,
         `encounter`.`date_changed` AS `date_changed`
	FROM `encounter`
	WHERE (`encounter`.`encounter_type` = 9 AND `encounter`.`voided` = 0);

DROP FUNCTION IF EXISTS patient_date_enrolled;

DELIMITER $$
CREATE FUNCTION patient_date_enrolled(my_patient_id int) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE my_start_date DATE;
DECLARE min_start_date DATETIME;
DECLARE arv_concept_id INT(11);

SET arv_concept_id = (SELECT concept_id FROM concept_name WHERE name ='ANTIRETROVIRAL DRUGS' LIMIT 1);

SET my_start_date = (SELECT DATE(o.start_date) FROM drug_order d INNER JOIN orders o ON d.order_id = o.order_id AND o.voided = 0 WHERE o.patient_id = my_patient_id AND drug_inventory_id IN(SELECT drug_id FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = arv_concept_id)) AND d.quantity > 0 AND o.start_date = (SELECT min(start_date) FROM drug_order d INNER JOIN orders o ON d.order_id = o.order_id AND o.voided = 0 WHERE d.quantity > 0 AND o.patient_id = my_patient_id AND drug_inventory_id IN(SELECT drug_id FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = arv_concept_id))) LIMIT 1);


RETURN my_start_date;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS date_antiretrovirals_started;

DELIMITER $$
CREATE FUNCTION date_antiretrovirals_started(set_patient_id INT, min_state_date DATE) RETURNS DATE
BEGIN

DECLARE date_started DATE;
DECLARE estimated_art_date DATE;
DECLARE estimated_art_date_months  VARCHAR(45);


SET date_started = (SELECT LEFT(value_datetime,10) FROM obs WHERE concept_id = 2516 AND encounter_id > 0 AND person_id = set_patient_id AND voided = 0 LIMIT 1);

IF date_started IS NULL then
  SET estimated_art_date_months = (SELECT value_text FROM obs WHERE encounter_id > 0 AND concept_id = 2516 AND person_id = set_patient_id AND voided = 0 LIMIT 1);
  SET min_state_date = (SELECT obs_datetime FROM obs WHERE encounter_id > 0 AND concept_id = 2516 AND person_id = set_patient_id AND voided = 0 LIMIT 1);

  IF estimated_art_date_months = "6 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 6 MONTH));
  ELSEIF estimated_art_date_months = "12 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 12 MONTH));
  ELSEIF estimated_art_date_months = "18 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 18 MONTH));
  ELSEIF estimated_art_date_months = "24 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 24 MONTH));
  ELSEIF estimated_art_date_months = "48 months" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 48 MONTH));
  ELSEIF estimated_art_date_months = "Over 2 years" THEN set date_started = (SELECT DATE_SUB(min_state_date, INTERVAL 60 MONTH));
  ELSE
    SET date_started = patient_start_date(set_patient_id);
  END IF;
END IF;

RETURN date_started;
END$$
DELIMITER ;

-- The date of the first On ARVs state for each patient
DROP TABLE IF EXISTS `earliest_start_date`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `earliest_start_date` AS
  select
      `p`.`patient_id` AS `patient_id`,
      `pe`.`gender` AS `gender`,
      `pe`.`birthdate`,
      date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
      cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
      `person`.`death_date` AS `death_date`,
      (select timestampdiff(year, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_at_initiation`,
      (select timestampdiff(day, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_in_days`
  from
      ((`patient_program` `p`
      left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
      left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
      left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
  where
      ((`p`.`voided` = 0)
          and (`s`.`voided` = 0)
          and (`p`.`program_id` = 1)
          and (`s`.`state` = 7))
  group by `p`.`patient_id`;

-- The date of the first On ARVs state for each patient
DROP TABLE IF EXISTS `patients_on_arvs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `patients_on_arvs` AS
    select
        `p`.`patient_id` AS `patient_id`,
        `person`.`birthdate`,
        date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
        `person`.`death_date` AS `death_date`,
        `person`.`gender` AS `gender`,
        ((to_days(date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`))) - to_days(`person`.`birthdate`)) / 365.25) AS `age_at_initiation`,
        (to_days(min(`s`.`start_date`)) - to_days(`person`.`birthdate`)) AS `age_in_days`
    from
        ((`patient_program` `p`
        left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
        left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
    where
        ((`p`.`voided` = 0)
            and (`s`.`voided` = 0)
            and (`p`.`program_id` = 1)
            and (`s`.`state` = 7))
    group by `p`.`patient_id`;

-- reason_ or art eligibility obs
DROP TABLE IF EXISTS `reason_for_art_eligibility_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  	VIEW `reason_for_art_eligibility_obs` AS
    select
        `o`.`person_id` AS `person_id`,
        `o`.`concept_id` AS `concept_id`,
        `o`.`obs_datetime` AS `obs_datetime`,
        `n`.`name` AS `name`
    from
        (`obs` `o`
        left join `concept_name` `n` ON (((`n`.`concept_id` = `o`.`value_coded`)
            and (`n`.`concept_name_type` = 'FULLY_SPECIFIED')
            and (`n`.`voided` = 0))))
    where
        ((`o`.`concept_id` = 7563)
            and (`o`.`voided` = 0))
    order by `o`.`obs_datetime` desc;

-- The date of the first On ARVs state for each patient
DROP TABLE IF EXISTS `patient_first_arv_amount_dispensed`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `patient_first_arv_amount_dispensed` AS
    select
        `enc`.`encounter_id` AS `encounter_id`,
        `enc`.`encounter_type` AS `encounter_type`,
        `enc`.`patient_id` AS `patient_id`,
        `enc`.`provider_id` AS `provider_id`,
        `enc`.`location_id` AS `location_id`,
        `enc`.`form_id` AS `form_id`,
        `enc`.`encounter_datetime` AS `encounter_datetime`,
        `enc`.`creator` AS `creator`,
        `enc`.`date_created` AS `date_created`,
        `enc`.`voided` AS `voided`,
        `enc`.`voided_by` AS `voided_by`,
        `enc`.`date_voided` AS `date_voided`,
        `enc`.`void_reason` AS `void_reason`,
        `enc`.`uuid` AS `uuid`,
        `enc`.`changed_by` AS `changed_by`,
        `enc`.`date_changed` AS `date_changed`
    from
        `encounter` `enc`
    where
        ((`enc`.`encounter_type` = 54)
            and (`enc`.`voided` = 0)
            and (cast(`enc`.`encounter_datetime` as date) = (select
                cast(min(`e`.`encounter_datetime`) as date)
            from
                `encounter` `e`
            where
                ((`e`.`patient_id` = `enc`.`patient_id`)
                    and (`e`.`encounter_type` = `enc`.`encounter_type`)
                    and (`e`.`voided` = 0)))));

-- 7937 = Ever registered at ART clinic
DROP TABLE IF EXISTS `ever_registered_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `ever_registered_obs` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 7937) AND (`obs`.`voided` = 0))
  AND (`obs`.`value_coded` = 1065);

DROP TABLE IF EXISTS `patient_pregnant_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patient_pregnant_obs` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  INNER JOIN `person` ON ((`person`.`person_id` = `obs`.`person_id`))
  WHERE ((`obs`.`concept_id` IN (6131,1755, 7972)) AND
         (`obs`.`value_coded` = 1065) AND
         (`obs`.`voided` = 0) AND
         (`person`.`gender` = 'F'));

DROP TABLE IF EXISTS `patient_state_on_arvs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patient_state_on_arvs` AS
  SELECT `patient_state`.`patient_state_id` AS `patient_state_id`,
         `patient_state`.`patient_program_id` AS `patient_program_id`,
         `patient_state`.`state` AS `state`,
         `patient_state`.`start_date` AS `start_date`,
         `patient_state`.`end_date` AS `end_date`,
         `patient_state`.`creator` AS `creator`,
         `patient_state`.`date_created` AS `date_created`,
         `patient_state`.`changed_by` AS `changed_by`,
         `patient_state`.`date_changed` AS `date_changed`,
         `patient_state`.`voided` AS `voided`,
         `patient_state`.`voided_by` AS `voided_by`,
         `patient_state`.`date_voided` AS `date_voided`,
         `patient_state`.`void_reason` AS `void_reason`,
         `patient_state`.`uuid` AS `uuid`
  FROM `patient_state`
  WHERE (`patient_state`.`state` = 7 AND `patient_state`.`voided` = 0);

DROP TABLE IF EXISTS `regimen_observation`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `regimen_observation` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 2559) AND (`obs`.`voided` = 0));

DROP TABLE IF EXISTS `start_date_observation`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `start_date_observation` AS
  SELECT `obs`.`person_id` AS `person_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`value_datetime` AS `value_datetime`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 2516) AND (`obs`.`voided` = 0))
  GROUP BY `obs`.`person_id`,`obs`.`value_datetime`;

DROP TABLE IF EXISTS `tb_status_observations`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `tb_status_observations` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 7459) and (`obs`.`voided` = 0));

-- The following 2 views will be used in calculation of defaulted dates
DROP TABLE IF EXISTS `amount_dispensed_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `amount_dispensed_obs` AS
  SELECT
    `o`.`person_id`,
    `o`.`encounter_id`,
    `o`.`order_id`,
    `o`.`obs_datetime`,
    `do`.`drug_inventory_id`,
    `do`.`equivalent_daily_dose`,
    `ord`.`start_date`,
    `o`.`value_numeric`
FROM
    `obs` `o`
        INNER JOIN
    `orders` `ord` ON `o`.`order_id` = `ord`.`order_id` and `ord`.`voided` = 0
        INNER JOIN
    `drug_order` `do` ON `ord`.`order_id` = `do`.`order_id`
        INNER JOIN
    `arv_drug` `ad` ON `do`.`drug_inventory_id` = `ad`.`drug_id`
WHERE
    `o`.`concept_id` = 2834 AND `o`.`voided` = 0;

DROP TABLE IF EXISTS `amount_brought_back_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `amount_brought_back_obs` AS
SELECT
    `o`.`person_id`,
    `o`.`encounter_id`,
    `o`.`order_id`,
    `o`.`obs_datetime`,
    `do`.`drug_inventory_id`,
    `do`.`equivalent_daily_dose`,
    `o`.`value_numeric`,
    `do`.`quantity`
FROM
    `obs` `o`
        INNER JOIN
    `drug_order` `do` ON `o`.`order_id` = `do`.`order_id`
        INNER JOIN
    `arv_drug` `ad` ON `do`.`drug_inventory_id` = `ad`.`drug_id`
WHERE
    `o`.`concept_id` = 2540 AND `o`.`voided` = 0;

DROP TABLE IF EXISTS `reason_for_eligibility_obs`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `reason_for_eligibility_obs` AS
SELECT
    `e`.`patient_id`, `n`.`name` AS `reason_for_eligibility`, `o`.`obs_datetime`, `e`.`earliest_start_date`, `e`.`date_enrolled` AS `date_enrolled`
FROM
    `earliest_start_date` `e`
        LEFT JOIN
    `obs` `o` ON `e`.`patient_id` = `o`.`person_id`
        AND `o`.`concept_id` = 7563
        AND `o`.`voided` = 0
        LEFT JOIN
    `concept_name` `n` ON `n`.`concept_id` = `o`.`value_coded`
        AND `n`.`concept_name_type` = 'FULLY_SPECIFIED'
        AND `n`.`voided` = 0
ORDER BY `e`.`patient_id` , `o`.`obs_datetime` DESC;

DROP TABLE IF EXISTS `patients_with_has_transfer_letter_yes`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patients_with_has_transfer_letter_yes` AS
SELECT
    `o`.`person_id`, `p`.`gender`, `o`.`obs_datetime`, `o`.`date_created`, `e`.`earliest_start_date`
FROM
    `obs` `o`
        INNER JOIN
    `person` `p` ON `p`.`person_id` = `o`.`person_id`
        AND `p`.`voided` = 0
        AND `o`.`voided` = 0
        INNER JOIN
    `earliest_start_date` `e` ON `e`.`patient_id` = `o`.`person_id`
WHERE
    `o`.`concept_id` = 6393
        AND `o`.`value_coded` = 1065
        AND `o`.`voided` = 0;

DROP TABLE IF EXISTS `all_patients_attributes`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `all_patients_attributes` AS
SELECT
    `person_id`,
    MAX(CASE WHEN `person_attribute_type_id` = 13 THEN `value` END) AS `occupation`,
    MAX(CASE WHEN `person_attribute_type_id` = 12 THEN `value` END) AS `cell_phone`,
    MAX(CASE WHEN `person_attribute_type_id` = 14 THEN `value` END) AS `home_phone`,
    MAX(CASE WHEN `person_attribute_type_id` = 15 THEN `value` END) AS `office_phone`
FROM
    `person_attribute`
WHERE `voided` = 0
GROUP BY `person_id`;

DROP TABLE IF EXISTS `all_patient_identifiers`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `all_patient_identifiers` AS
SELECT
    `patient_id`,
    MAX(CASE WHEN `identifier_type` = 1 THEN `identifier` END) AS `openmrs_ident_type`,
    MAX(CASE WHEN `identifier_type` = 3 THEN `identifier` END) AS `national_id`,
    MAX(CASE WHEN `identifier_type` = 4 THEN `identifier` END) AS `arv_number`,
    MAX(CASE WHEN `identifier_type` = 2 THEN `identifier` END) AS `legacy_id`,
    MAX(CASE WHEN `identifier_type` = 5 THEN `identifier` END) AS `prev_art_number`,
    MAX(CASE WHEN `identifier_type` = 7 THEN `identifier` END) AS `tb_number`,
    MAX(CASE WHEN `identifier_type` = 17 THEN `identifier` END) AS `filing_number`,
    MAX(CASE WHEN `identifier_type` = 18 THEN `identifier` END) AS `archived_filing_number`,
    MAX(CASE WHEN `identifier_type` = 22 THEN `identifier` END) AS `pre_art_number`
FROM
    `patient_identifier`
WHERE `voided` = 0
GROUP BY `patient_id`;

DROP TABLE IF EXISTS `all_person_addresses`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `all_person_addresses` AS
SELECT
    `p`. *
FROM
    `person_address` `p`
WHERE
    `p`.`person_address_id` = (SELECT
            MAX(`pad`.`person_address_id`)
        FROM
            `person_address` `pad`
        WHERE
            `pad`.`person_id` = `p`.`person_id`
                AND `pad`.`voided` = 0)
        AND `p`.`voided` = 0;

DROP TABLE IF EXISTS `guardians`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `guardians` AS
SELECT
    `person_a` AS `patient_id`,
    `person_b` AS `guardian_id`,
    `per`.`gender` AS `gender`,
    `p`.`given_name` AS `given_name`,
    `p`.`family_name` AS `family_name`,
    `p`.`middle_name` AS `middle_name`,
    `per`.`birthdate_estimated` AS `birthdate_estimated`,
    `per`.`birthdate` AS `birthdate`,
    `pa`.`address2` AS `home_district`,
    `pa`.`state_province` AS `current_district`,
    `pa`.`address1` AS `landmark`,
    `pa`.`city_village` AS `current_residence`,
    `pa`.`county_district` AS `traditional_authority`
FROM
    `relationship` `r`
        INNER JOIN
    `person_name` `p` ON `p`.`person_id` = `r`.`person_b`
        LEFT JOIN
    `all_person_addresses` `pa` ON `pa`.`person_id` = `p`.`person_id`
        INNER JOIN
    `person` `per` ON `per`.`person_id` = `p`.`person_id` AND `p`.`voided` = 0
WHERE
    `r`.`voided` = 0
AND `r`.`person_a` IN (SELECT `e`.`patient_id` FROM `earliest_start_date` `e`)
ORDER BY `patient_id`;

DROP TABLE IF EXISTS `patients_demographics`;
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patients_demographics` AS
SELECT
    `esd`.`patient_id`,
    `p`.`given_name` AS `given_name`,
    `p`.`family_name` AS `family_name`,
    `p`.`middle_name` AS `middle_name`,
    `per`.`gender` AS `gender`,
    `per`.`birthdate_estimated`,
    `per`.`birthdate` AS `birthdate`,
    `pa`.`address2` AS `home_district`,
    `pa`.`state_province` AS `current_district`,
    `pa`.`address1` AS `landmark`,
    `pa`.`city_village` AS `current_residence`,
    `pa`.`county_district` AS `traditional_authority`,
    `esd`.`date_enrolled`,
    `esd`.`earliest_start_date`,
    `esd`.`death_date`,
    `esd`.`age_at_initiation`,
    `esd`.`age_in_days`
FROM
    `earliest_start_date` `esd`
        INNER JOIN
    `person_name` `p` ON `p`.`person_id` = `esd`.`patient_id` and `p`.`voided` = 0
        LEFT JOIN
    `all_person_addresses` `pa` ON `pa`.`person_id` = `p`.`person_id` and `pa`.`voided` = 0
        INNER JOIN
    `person` `per` ON `per`.`person_id` = `p`.`person_id` and `per`.`voided` = 0
GROUP BY `esd`.`patient_id`
ORDER BY `patient_id`;

DROP FUNCTION IF EXISTS earliest_start_date_at_clinic;

DELIMITER $$
CREATE FUNCTION earliest_start_date_at_clinic(set_patient_id INT) RETURNS DATE
BEGIN

DECLARE date_started DATE;

SET date_started = (SELECT MIN(start_date) FROM patient_state s INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id WHERE s.voided = 0 AND s.state = 7 AND p.program_id = 1 AND p.patient_id = set_patient_id);

RETURN date_started;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS patient_outcome;

DELIMITER $$
CREATE FUNCTION `patient_outcome`(patient_id INT, visit_date date) RETURNS varchar(25)
BEGIN
DECLARE set_program_id INT;
DECLARE set_patient_state INT;
DECLARE set_outcome varchar(25);
DECLARE set_date_started date;
DECLARE set_patient_state_died INT;
DECLARE set_died_concept_id INT;
DECLARE set_timestamp DATETIME;
DECLARE dispensed_quantity INT;

SET set_timestamp = TIMESTAMP(CONCAT(DATE(visit_date), ' ', '23:59:59'));
SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);

SET set_patient_state = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC LIMIT 1);

IF set_patient_state = 1 THEN
  SET set_patient_state = current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  ELSE
    SET set_outcome = 'Pre-ART (Continue)';
  END IF;
END IF;

IF set_patient_state = 2   THEN
  SET set_outcome = 'Patient transferred out';
END IF;

IF set_patient_state = 3 OR set_patient_state = 127 THEN
  SET set_outcome = 'Patient died';
END IF;

/* ............... This block of code checks if the patient has any state that is "died" */
IF set_patient_state != 3 AND set_patient_state != 127 THEN
  SET set_patient_state_died = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) AND state = 3 ORDER BY patient_state.patient_state_id DESC, patient_state.date_created DESC, start_date DESC LIMIT 1);

  SET set_died_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Patient died' LIMIT 1);

  IF set_patient_state_died IN(SELECT program_workflow_state_id FROM program_workflow_state WHERE concept_id = set_died_concept_id AND retired = 0) THEN
    SET set_outcome = 'Patient died';
    SET set_patient_state = 3;
  END IF;
END IF;
/* ....................  ends here .................... */


IF set_patient_state = 6 THEN
  SET set_outcome = 'Treatment stopped';
END IF;

IF set_patient_state = 7 OR set_outcome = 'Pre-ART (Continue)' OR set_outcome IS NULL THEN
  SET set_patient_state = current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_patient_state = 0 OR set_outcome IS NULL THEN

    SET dispensed_quantity = (SELECT d.quantity
      FROM orders o
      INNER JOIN drug_order d ON d.order_id = o.order_id
      INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
      WHERE o.patient_id = patient_id AND o.voided = 0
      AND d.drug_inventory_id IN(
        SELECT DISTINCT(drug_id) FROM drug WHERE
        concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = 1085)
    ) AND DATE(o.start_date) <= visit_date AND d.quantity > 0 ORDER BY start_date DESC LIMIT 1);

    IF dispensed_quantity > 0 THEN
      SET set_outcome = 'On antiretrovirals';
    END IF;
  END IF;
END IF;

IF set_outcome IS NULL THEN
  SET set_patient_state = current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_outcome IS NULL THEN
    SET set_outcome = 'Unknown';
  END IF;

END IF;

RETURN set_outcome;
END$$
DELIMITER ;

--
-- Dumping routines for database 'bart2'
--
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DROP FUNCTION IF EXISTS `age`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `age`(birthdate varchar(10),visit_date varchar(10),date_created varchar(10),est int) RETURNS int(11)
    DETERMINISTIC
BEGIN
DECLARE year_when_patient_created INT;
DECLARE cul_age INT;

DECLARE birth_year INT;
DECLARE birth_month INT;
DECLARE birth_day INT;

DECLARE cur_year INT;
DECLARE cur_month INT;
DECLARE cur_day INT;


DECLARE visit_year INT;
DECLARE visit_month INT;
DECLARE visit_day INT;

DECLARE cul_year INT;
DECLARE cul_month INT;
DECLARE cul_day INT;

SET year_when_patient_created = (SELECT YEAR(FROM_DAYS(TO_DAYS(date_created))));

set birth_year = (SELECT YEAR(FROM_DAYS(TO_DAYS(birthdate))));
set birth_month = (SELECT MONTH(FROM_DAYS(TO_DAYS(birthdate))));
set birth_day = (SELECT DAY(FROM_DAYS(TO_DAYS(birthdate))));

set cur_year = (SELECT YEAR(CURDATE()));
set cur_month = (SELECT MONTH(CURDATE()));
set cur_day = (SELECT DAY(CURDATE()));

set visit_year = (SELECT YEAR(FROM_DAYS(TO_DAYS(visit_date))));
set visit_month = (SELECT MONTH(FROM_DAYS(TO_DAYS(visit_date))));
set visit_day = (SELECT DAY(FROM_DAYS(TO_DAYS(visit_date))));

SET cul_year 	= (visit_year - birth_year);
SET cul_month = (visit_month - birth_month);
SET cul_day 	=	(visit_day - birth_day);


IF ((cul_day < 0) = 1) THEN SET cul_day = -1;
ELSEIF ((cul_day < 0) = 0) THEN SET cul_day = 0;
END IF;

SET cul_month = (cul_month + cul_day);

IF ((cul_month < 0) = 1) THEN SET cul_month = -1;
ELSEIF ((cul_month < 0) = 0) THEN SET cul_month = 0;
END IF;

SET cul_age = (cul_year + cul_month);
SET cul_age = ( (cul_age + (est + birth_month = 7 + birth_day = 1 + visit_month < birth_month + year_when_patient_created = visit_year))  );

RETURN cul_age;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `age_group`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `age_group`(birthdate varchar(10),visit_date varchar(10),date_created varchar(10),est int) RETURNS varchar(25) CHARSET latin1
    DETERMINISTIC
BEGIN
DECLARE avg VARCHAR(25);
DECLARE mths INT;
DECLARE n INT;

set avg="none";
set n =  (SELECT age(birthdate,visit_date,date_created,est));
set mths = (SELECT extract(MONTH FROM DATE(visit_date))-extract(MONTH FROM DATE(birthdate)));

if n >= 1 AND n < 5 then set avg="1 to < 5";
elseif n >= 5 AND n <= 14 then set avg="5 to 14";
elseif n > 14 AND n < 20 then set avg="> 14 to < 20";
elseif n >= 20 AND n < 30 then set avg="20 to < 30";
elseif n >= 30 AND n < 40 then set avg="30 to < 40";
elseif n >= 40 AND n < 50 then set avg="40 to < 50";
elseif n >= 50 then set avg="50 and above";
end if;

if mths >= 0 AND mths < 6 and avg="none" then set avg="< 6 months";
elseif mths >= 6 AND n < 12 and avg="none"then set avg="6 months to < 1 yr";
end if;

RETURN avg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_defaulter`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_defaulter`(my_patient_id INT, my_end_date DATETIME) RETURNS int(1)
BEGIN
	DECLARE done INT DEFAULT FALSE;
	DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
	DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL;
	DECLARE my_drug_id, flag INT;

	DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, d.quantity, o.start_date FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id
		GROUP BY o.patient_id;

	OPEN cur1;

	SET flag = 0;

	read_loop: LOOP
		FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

		IF done THEN
			CLOSE cur1;
			LEAVE read_loop;
		END IF;

		IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 2 DAY), ((my_quantity + my_pill_count)/my_daily_dose));

			IF my_expiry_date IS NULL THEN
				SET my_expiry_date = @expiry_date;
			END IF;

			IF @expiry_date < my_expiry_date THEN
				SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF DATEDIFF(my_end_date, my_expiry_date) > 60 THEN
        SET flag = 1;
    END IF;

	RETURN flag;
END */;;
DELIMITER ;

/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `drug_pill_count`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `drug_pill_count`(my_patient_id INT, my_drug_id INT, my_date DATE) RETURNS DECIMAL
BEGIN
	DECLARE done INT DEFAULT FALSE;
	DECLARE my_pill_count, my_total_text, my_total_numeric DECIMAL;

	DECLARE cur1 CURSOR FOR SELECT SUM(ob.value_numeric), SUM(CAST(ob.value_text AS DECIMAL)) FROM obs ob
                        INNER JOIN drug_order do ON ob.order_id = do.order_id
                        INNER JOIN orders o ON do.order_id = o.order_id
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = 2540
                        AND ob.voided = 0
                        AND o.voided = 0
                        AND do.drug_inventory_id = my_drug_id
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	OPEN cur1;

	SET my_pill_count = 0;

	read_loop: LOOP
		FETCH cur1 INTO my_total_numeric, my_total_text;

		IF done THEN
			CLOSE cur1;
			LEAVE read_loop;
		END IF;

        IF my_total_numeric IS NULL THEN
            SET my_total_numeric = 0;
        END IF;

        IF my_total_text IS NULL THEN
            SET my_total_text = 0;
        END IF;

        SET my_pill_count = my_total_numeric + my_total_text;
    END LOOP;

	RETURN my_pill_count;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_state_for_program`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_state_for_program`(my_patient_id INT, my_program_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
  SET @state_id = NULL;
  SET @new_state_id = NULL;
	SELECT  patient_program_id INTO @patient_program_id FROM patient_program
			WHERE patient_id = my_patient_id
				AND program_id = my_program_id
				AND voided = 0
				ORDER BY patient_program_id DESC LIMIT 1;


	SELECT state, start_date INTO @state_id, @start_date FROM patient_state
		WHERE patient_program_id = @patient_program_id
			AND voided = 0
			AND start_date <= my_end_date
		ORDER BY start_date DESC, date_created DESC, patient_state_id DESC LIMIT 1;

   IF ( @state_id != 3 ) THEN

      SELECT state INTO @new_state_id FROM patient_state
		   WHERE patient_program_id = @patient_program_id
			AND voided = 0
			AND start_date = @start_date
         AND state = 3 LIMIT 1;
   END IF;

    IF ( @new_state_id IS NOT NULL ) THEN
        RETURN @new_state_id;
    END IF;

	RETURN @state_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_state_for_patient_in_flat_tables`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_state_for_patient_in_flat_tables`(my_patient_id INT, my_end_date DATETIME) RETURNS varchar(255)
BEGIN
  SET @state_id = NULL;
	SELECT current_hiv_program_state INTO @state_id FROM flat_table2
    WHERE current_hiv_program_state IS NOT NULL and current_hiv_program_start_date IS NOT NULL
      AND patient_id = my_patient_id
      AND current_hiv_program_start_date <= my_end_date
    ORDER BY patient_id, current_hiv_program_start_date DESC
    LIMIT 1;

	RETURN @state_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_hiv_program_start_date_max`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_hiv_program_start_date_max`(my_patient_id INT, my_end_date DATETIME) RETURNS varchar(10) CHARSET latin1
    DETERMINISTIC
BEGIN
  SET @patient_id = NULL;
	SELECT max(ft3.current_hiv_program_start_date) INTO @patient_id FROM flat_table2 ft3
    WHERE ft3.patient_id = my_patient_id
	    AND ft3.current_hiv_program_start_date <= my_end_date
	    AND ft3.current_hiv_program_state = 'On antiretrovirals'
	    AND ft3.current_hiv_program_start_date IS NOT NULL;

	RETURN @patient_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `last_text_for_obs`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `last_text_for_obs`(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_regimem_given INT, unknown_regimen_value INT, my_end_date DATETIME) RETURNS varchar(255)
BEGIN
  SET @obs_value = NULL;
  SET @encounter_id = NULL;

	SELECT o.encounter_id INTO @encounter_id FROM encounter e
			INNER JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id IN (my_concept_id, @unknown_drug_concept_id) AND o.voided = 0
		WHERE e.encounter_type = my_encounter_type_id
			AND e.voided = 0
			AND e.patient_id = my_patient_id
			AND e.encounter_datetime <= my_end_date
		ORDER BY e.encounter_datetime DESC LIMIT 1;

	SELECT cn.name INTO @obs_value FROM obs o
			LEFT JOIN concept_name cn ON o.value_coded = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED'
		WHERE encounter_id = @encounter_id
			AND o.voided = 0
			AND o.concept_id = my_concept_id
			AND o.voided = 0 LIMIT 1;

  IF @obs_value IS NULL THEN
    		SELECT 'unknown_drug_value' INTO @obs_value FROM obs
    			WHERE encounter_id = @encounter_id
    				AND voided = 0
    				AND concept_id = my_regimem_given
    				AND value_coded = unknown_regimen_value
    				AND voided = 0 LIMIT 1;

  END IF;

	IF @obs_value IS NULL THEN
		SELECT value_text INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;
	END IF;

	IF @obs_value IS NULL THEN
		SELECT value_numeric INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;
	END IF;

	RETURN @obs_value;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_text_for_obs`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_text_for_obs`(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS VARCHAR(255)
BEGIN
  SET @obs_value = NULL;
	SELECT encounter_id INTO @encounter_id FROM encounter
		WHERE encounter_type = my_encounter_type_id
			AND voided = 0
			AND patient_id = my_patient_id
			AND encounter_datetime <= my_end_date
		ORDER BY encounter_datetime DESC LIMIT 1;

	SELECT cn.name INTO @obs_value FROM obs o
			LEFT JOIN concept_name cn ON o.value_coded = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED'
		WHERE encounter_id = @encounter_id
			AND o.voided = 0
			AND o.concept_id = my_concept_id
			AND o.voided = 0 LIMIT 1;

	IF @obs_value IS NULL THEN
		SELECT value_text INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;
	END IF;

	IF @obs_value IS NULL THEN
		SELECT value_numeric INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;
	END IF;

	RETURN @obs_value;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_value_for_obs`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_value_for_obs`(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
  SET @obs_value_coded = NULL;
	SELECT encounter_id INTO @encounter_id FROM encounter
		WHERE encounter_type = my_encounter_type_id
			AND voided = 0
			AND patient_id = my_patient_id
			AND encounter_datetime <= my_end_date
		ORDER BY encounter_datetime DESC LIMIT 1;

	SELECT value_coded INTO @obs_value_coded FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;

	RETURN @obs_value_coded;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_value_for_obs_at_initiation`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_value_for_obs_at_initiation`(my_patient_id INT, my_earliest_start_date DATETIME, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
	DECLARE obs_value_coded, my_encounter_id INT;

	SELECT encounter_id INTO my_encounter_id FROM encounter
		WHERE encounter_type = my_encounter_type_id
			AND voided = 0
			AND patient_id = my_patient_id
			AND encounter_datetime <= ADDDATE(DATE(my_earliest_start_date), 1)
		ORDER BY encounter_datetime DESC LIMIT 1;

	IF my_encounter_id IS NULL THEN
		SELECT encounter_id INTO my_encounter_id FROM encounter
			WHERE encounter_type = my_encounter_type_id
				AND voided = 0
				AND patient_id = my_patient_id
				AND encounter_datetime <= my_end_date
                AND encounter_datetime >= ADDDATE(DATE(my_earliest_start_date), 1)
			ORDER BY encounter_datetime LIMIT 1;
	END IF;

	SELECT value_coded INTO obs_value_coded FROM obs
			WHERE encounter_id = my_encounter_id
				AND voided = 0
				AND concept_id = my_concept_id
				AND voided = 0 LIMIT 1;

	RETURN obs_value_coded;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `patient_start_date`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `patient_start_date`(patient_id int) RETURNS varchar(10) CHARSET latin1
    DETERMINISTIC
BEGIN
DECLARE start_date VARCHAR(10);
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

set dispension_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED');
set arv_concept = (SELECT concept_id FROM concept_name WHERE name = "ANTIRETROVIRAL DRUGS");

set start_date = (SELECT MIN(DATE(obs_datetime)) FROM obs WHERE voided = 0 AND person_id = patient_id AND concept_id = dispension_concept_id AND value_drug IN (SELECT drug_id FROM drug d WHERE d.concept_id IN (SELECT cs.concept_id FROM concept_set cs WHERE cs.concept_set = arv_concept)));

RETURN start_date;
END */;;

DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;


DROP FUNCTION IF EXISTS `current_defaulter_date`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_defaulter_date`(my_patient_id INT, my_end_date DATETIME) RETURNS DATE
BEGIN
	DECLARE done INT DEFAULT FALSE;
	DECLARE my_start_date, my_expiry_date, my_obs_datetime, my_defaulted_date DATETIME;
	DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL;
	DECLARE my_drug_id, flag INT;

	DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, d.quantity, o.start_date FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id
		GROUP BY o.patient_id;

	OPEN cur1;

	SET flag = 0;

	read_loop: LOOP
		FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

		IF done THEN
			CLOSE cur1;
			LEAVE read_loop;
		END IF;

		IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR my_daily_dose IS NULL OR LENGTH(my_daily_dose) < 1 THEN
        SET my_daily_dose = 1;
      END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(my_start_date, ((my_quantity + my_pill_count)/my_daily_dose));

			IF my_expiry_date IS NULL THEN
				SET my_expiry_date = @expiry_date;
			END IF;

			IF @expiry_date < my_expiry_date THEN
				SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) >= 60 THEN
        SET my_defaulted_date = ADDDATE(my_expiry_date, 60);
    END IF;

	RETURN my_defaulted_date;
END */;;
DELIMITER ;

/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `patient_max_defaulted_date`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `patient_max_defaulted_date`(m_patient_id int, my_end_date DATETIME) RETURNS DATE
BEGIN

DECLARE my_defaulted_date DATETIME;

set my_defaulted_date = (SELECT MAX(defaulted_date) FROM patient_defaulted_dates WHERE patient_id = m_patient_id AND start_date <= my_end_date);

RETURN my_defaulted_date;
END */;;

/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
-- Dump completed on 2012-05-03 21:13:17


DROP FUNCTION IF EXISTS `patient_reason_for_starting_art`;



CREATE FUNCTION patient_reason_for_starting_art(my_patient_id INT) RETURNS INT
BEGIN
  DECLARE reason_for_art_eligibility INT DEFAULT 0;
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime  LIMIT 1);
  SET reason_for_art_eligibility = (coded_concept_id);


  RETURN reason_for_art_eligibility;
END;


  DROP FUNCTION IF EXISTS `patient_reason_for_starting_art_text`;

CREATE FUNCTION patient_reason_for_starting_art_text(my_patient_id INT) RETURNS VARCHAR(255)
BEGIN
  DECLARE reason_for_art_eligibility VARCHAR(255);
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime  LIMIT 1);
  SET reason_for_art_eligibility = (SELECT name FROM concept_name WHERE concept_id = coded_concept_id AND LENGTH(name) > 0 LIMIT 1);

  RETURN reason_for_art_eligibility;
END;

DROP FUNCTION IF EXISTS `patient_current_regimen`;

CREATE FUNCTION `patient_current_regimen`(`my_patient_id` INT, `my_date` DATE) RETURNS VARCHAR(10)
BEGIN
  DECLARE max_obs_datetime DATETIME;
  DECLARE regimen VARCHAR(10) DEFAULT 'N/A';

  SET max_obs_datetime = (
    SELECT MAX(start_date)
    FROM orders
      INNER JOIN drug_order
        ON drug_order.order_id = orders.order_id
        AND drug_order.drug_inventory_id IN (SELECT * FROM arv_drug)
        AND orders.voided = 0
        AND DATE(orders.start_date) <= DATE(my_date)
    WHERE orders.patient_id = my_patient_id AND drug_order.quantity > 0
  );

  SET @drug_ids := (
    SELECT GROUP_CONCAT(DISTINCT(drug_order.drug_inventory_id) ORDER BY drug_order.drug_inventory_id ASC)
    FROM drug_order
      INNER JOIN arv_drug ON drug_order.drug_inventory_id = arv_drug.drug_id
      INNER JOIN orders ON drug_order.order_id = orders.order_id AND drug_order.quantity > 0
      INNER JOIN encounter
        ON encounter.encounter_id = orders.encounter_id
        AND encounter.voided = 0
        AND encounter.encounter_type = 25
    WHERE orders.voided = 0
      AND date(orders.start_date) = DATE(max_obs_datetime)
      AND encounter.patient_id = my_patient_id
    ORDER BY arv_drug.drug_id ASC
  );

  SET regimen = (
    SELECT name FROM (
      SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs,
             regimen_name.name AS name
      FROM moh_regimen_combination AS combo
        INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
        INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
      GROUP BY combo.regimen_combination_id
    ) AS regimens
    WHERE drugs = @drug_ids
  );

  IF regimen IS NULL THEN
    SET regimen = 'N/A';
  END IF;

  RETURN regimen;
END;;

DROP FUNCTION IF EXISTS `last_text_for_obs`;

CREATE FUNCTION last_text_for_obs(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_regimem_given INT, unknown_regimen_value INT, my_end_date DATETIME) RETURNS varchar(255)

BEGIN
  SET @obs_value = NULL;
  SET @encounter_id = NULL;

  SELECT o.encounter_id INTO @encounter_id FROM encounter e
  	INNER JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id IN (my_concept_id, @unknown_drug_concept_id) AND o.voided = 0
  WHERE e.encounter_type = my_encounter_type_id
  AND e.voided = 0
  AND e.patient_id = my_patient_id
  AND e.encounter_datetime <= my_end_date
  ORDER BY e.encounter_datetime DESC LIMIT 1;

  SELECT cn.name INTO @obs_value FROM obs o
  	LEFT JOIN concept_name cn ON o.value_coded = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED'
  WHERE encounter_id = @encounter_id
  AND o.voided = 0
  AND o.concept_id = my_concept_id
  AND o.voided = 0 LIMIT 1;

  IF @obs_value IS NULL THEN
    SELECT 'unknown_drug_value' INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_regimem_given
    AND (value_coded = unknown_regimen_value OR value_text = 'Unknown')
    AND voided = 0 LIMIT 1;
  END IF;

  IF @obs_value IS NULL THEN
    SELECT value_text INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_concept_id
    AND voided = 0 LIMIT 1;
  END IF;

  IF @obs_value IS NULL THEN
    SELECT value_numeric INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_concept_id
    AND voided = 0 LIMIT 1;
  END IF;

  RETURN @obs_value;
END;

DROP FUNCTION IF EXISTS `drug_pill_count`;

CREATE FUNCTION `drug_pill_count`(my_patient_id INT, my_drug_id INT, my_date DATE) RETURNS decimal(10,0)
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_pill_count, my_total_text, my_total_numeric DECIMAL;

  DECLARE cur1 CURSOR FOR SELECT SUM(ob.value_numeric), SUM(CAST(ob.value_text AS DECIMAL)) FROM obs ob
                        INNER JOIN drug_order do ON ob.order_id = do.order_id
                        INNER JOIN orders o ON do.order_id = o.order_id
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = 2540
                        AND ob.voided = 0
                        AND o.voided = 0
                        AND do.drug_inventory_id = my_drug_id
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;

  DECLARE cur2 CURSOR FOR SELECT SUM(ob.value_numeric) FROM obs ob
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = (SELECT concept_id FROM drug WHERE drug_id = my_drug_id)
                        AND ob.voided = 0
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur1;

  SET my_pill_count = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_total_numeric, my_total_text;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

        IF my_total_numeric IS NULL THEN
            SET my_total_numeric = 0;
        END IF;

        IF my_total_text IS NULL THEN
            SET my_total_text = 0;
        END IF;

        SET my_pill_count = my_total_numeric + my_total_text;
    END LOOP;

  OPEN cur2;
  SET done = false;

  read_loop: LOOP
    FETCH cur2 INTO my_total_numeric;

    IF done THEN
      CLOSE cur2;
      LEAVE read_loop;
    END IF;

        IF my_total_numeric IS NULL THEN
            SET my_total_numeric = 0;
        END IF;

        SET my_pill_count = my_total_numeric + my_pill_count;
    END LOOP;

  RETURN my_pill_count;
END;


DROP FUNCTION IF EXISTS `current_defaulter`;

CREATE FUNCTION `current_defaulter`(my_patient_id INT, my_end_date DATETIME) RETURNS int(1)
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(6, 2);
  DECLARE my_drug_id, flag INT;

  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
    GROUP BY o.patient_id;

  OPEN cur1;

  SET flag = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 2 DAY), ((my_quantity + my_pill_count)/my_daily_dose));

      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;

      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) > 60 THEN
        SET flag = 1;
    END IF;

  RETURN flag;
END;

DROP FUNCTION IF EXISTS `current_defaulter_date`;
CREATE FUNCTION current_defaulter_date(my_patient_id INT, my_end_date date) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime, my_defaulted_date DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(6, 2);
  DECLARE my_drug_id, flag INT;

  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
    GROUP BY o.patient_id;

  OPEN cur1;

  SET flag = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR my_daily_dose IS NULL OR LENGTH(my_daily_dose) < 1 THEN
        SET my_daily_dose = 1;
      END IF;

      SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

      SET @expiry_date = ADDDATE(my_start_date, ((my_quantity + my_pill_count)/my_daily_dose));

      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;

      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
        END IF;
      END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, DATE(my_expiry_date), DATE(my_end_date)) >= 60 THEN
      SET my_defaulted_date = ADDDATE(my_expiry_date, 60);
    END IF;

  RETURN my_defaulted_date;
END;

/* ................................................................... */






/* ................................................................... */


DROP FUNCTION IF EXISTS `re_initiated_check`;

CREATE FUNCTION re_initiated_check(set_patient_id INT, set_date_enrolled DATE) RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
DECLARE re_initiated VARCHAR(15) DEFAULT 'N/A';
DECLARE check_one INT DEFAULT 0;
DECLARE check_two INT DEFAULT 0;

DECLARE yes_concept INT;
DECLARE no_concept INT;
DECLARE date_art_last_taken_concept INT;
DECLARE taken_arvs_concept INT;

set yes_concept = (SELECT concept_id FROM concept_name WHERE name ='YES' LIMIT 1);
set no_concept = (SELECT concept_id FROM concept_name WHERE name ='NO' LIMIT 1);
set date_art_last_taken_concept = (SELECT concept_id FROM concept_name WHERE name ='DATE ART LAST TAKEN' LIMIT 1);

set check_one = (SELECT e.patient_id FROM clinic_registration_encounter e INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = date_art_last_taken_concept AND o.voided = 0 WHERE ((o.concept_id = date_art_last_taken_concept AND (TIMESTAMPDIFF(day, o.value_datetime, o.obs_datetime)) > 14)) AND patient_date_enrolled(e.patient_id) = set_date_enrolled AND e.patient_id = set_patient_id GROUP BY e.patient_id);

if check_one >= 1 then set re_initiated ="Re-initiated";
elseif check_two >= 1 then set re_initiated ="Re-initiated";
end if;

if check_one = 'N/A' then
  set taken_arvs_concept = (SELECT concept_id FROM concept_name WHERE name ='HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS' LIMIT 1);
  set check_two = (SELECT e.patient_id FROM clinic_registration_encounter e INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = taken_arvs_concept AND o.voided = 0 WHERE  ((o.concept_id = taken_arvs_concept AND o.value_coded = no_concept)) AND patient_date_enrolled(e.patient_id) = set_date_enrolled AND e.patient_id = set_patient_id GROUP BY e.patient_id);

  if check_two >= 1 then set re_initiated ="Re-initiated";
  end if;
end if;

RETURN re_initiated;
END;


DROP FUNCTION IF EXISTS `died_in`;


CREATE FUNCTION died_in(set_patient_id INT, set_status VARCHAR(25), date_enrolled DATE) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE set_outcome varchar(25) default 'N/A';
DECLARE date_of_death DATE;
DECLARE num_of_days INT;

IF set_status = 'Patient died' THEN

  SET date_of_death = (
    SELECT COALESCE(death_date, outcome_date)
    FROM temp_patient_outcomes INNER JOIN temp_earliest_start_date USING (patient_id)
    WHERE cum_outcome = 'Patient died' AND patient_id = set_patient_id
  );

  IF date_of_death IS NULL THEN
    RETURN 'Unknown';
  END IF;


  set num_of_days = (TIMESTAMPDIFF(day, date(date_enrolled), date(date_of_death)));

  IF num_of_days <= 30 THEN set set_outcome ="1st month";
  ELSEIF num_of_days <= 60 THEN set set_outcome ="2nd month";
  ELSEIF num_of_days <= 91 THEN set set_outcome ="3rd month";
  ELSEIF num_of_days > 91 THEN set set_outcome ="4+ months";
  ELSEIF num_of_days IS NULL THEN set set_outcome = "Unknown";
  END IF;


END IF;

RETURN set_outcome;
END;

/*
-- The following are PEPFAR functions, used for PEPFAR reports; Disagreggated report and Defaulter list
--
*/

DROP FUNCTION IF EXISTS `current_pepfar_defaulter`;

CREATE  FUNCTION `current_pepfar_defaulter`(my_patient_id INT, my_end_date DATETIME) RETURNS int(1)
BEGIN
DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(6, 2);
  DECLARE my_drug_id, flag INT;

  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
      GROUP BY drug_inventory_id, DATE(start_date), daily_dose;


  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
    GROUP BY o.patient_id;

  OPEN cur1;

  SET flag = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 2 DAY), ((my_quantity + my_pill_count)/my_daily_dose));

      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;

      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) > 30 THEN
        SET flag = 1;
    END IF;

  RETURN flag;
END;

DROP FUNCTION IF EXISTS `current_pepfar_defaulter_date`;

CREATE FUNCTION `current_pepfar_defaulter_date`(my_patient_id INT, my_end_date DATETIME) RETURNS DATE
BEGIN
	DECLARE done INT DEFAULT FALSE;
	DECLARE my_start_date, my_expiry_date, my_obs_datetime, my_defaulted_date DATETIME;
	DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL(6, 2);
	DECLARE my_drug_id, flag INT;

	DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, SUM(d.quantity), o.start_date FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id
			GROUP BY drug_inventory_id, DATE(start_date), daily_dose;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id
		GROUP BY o.patient_id;

	OPEN cur1;

	SET flag = 0;

	read_loop: LOOP
		FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

		IF done THEN
			CLOSE cur1;
			LEAVE read_loop;
		END IF;

		IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR my_daily_dose IS NULL OR LENGTH(my_daily_dose) < 1 THEN
        SET my_daily_dose = 1;
      END IF;

            SET my_pill_count = drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(my_start_date, ((my_quantity + my_pill_count)/my_daily_dose));

			IF my_expiry_date IS NULL THEN
				SET my_expiry_date = @expiry_date;
			END IF;

			IF @expiry_date < my_expiry_date THEN
				SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, DATE(my_expiry_date), DATE(my_end_date)) >= 30 THEN
        SET my_defaulted_date = ADDDATE(my_expiry_date, 30);
    END IF;

	RETURN my_defaulted_date;
END;


/* ............................................... */

DROP FUNCTION IF EXISTS `patient_screened_for_tb`;

CREATE FUNCTION `patient_screened_for_tb`(my_patient_id INT, my_start_date DATE, my_end_date DATE) RETURNS INT
BEGIN
	DECLARE screened INT DEFAULT FALSE;
	DECLARE record_value INT;

  SET record_value = (SELECT ob.person_id FROM obs ob
    INNER JOIN temp_earliest_start_date e
    ON e.patient_id = ob.person_id
    WHERE ob.concept_id IN(
      SELECT GROUP_CONCAT(DISTINCT(concept_id)
      ORDER BY concept_id ASC) FROM concept_name
      WHERE name IN('TB treatment','TB status') AND voided = 0
    ) AND ob.voided = 0
    AND ob.obs_datetime = (
    SELECT MAX(t.obs_datetime) FROM obs t WHERE
    t.obs_datetime BETWEEN DATE_FORMAT(DATE(my_start_date), '%Y-%m-%d 00:00:00')
    AND DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
    AND t.person_id = ob.person_id AND t.concept_id IN(
      SELECT GROUP_CONCAT(DISTINCT(concept_id)
      ORDER BY concept_id ASC) FROM concept_name
      WHERE name IN('TB treatment','TB status') AND voided = 0))
    AND ob.person_id = my_patient_id
    GROUP BY ob.person_id);

  IF record_value IS NOT NULL THEN
    SET screened = TRUE;
  END IF;

	RETURN screened;
END;


DROP FUNCTION IF EXISTS `patient_given_ipt`;

CREATE FUNCTION `patient_given_ipt`(my_patient_id INT, my_start_date DATE, my_end_date DATE) RETURNS INT
BEGIN
	DECLARE given INT DEFAULT FALSE;
	DECLARE record_value INT;

  SET record_value = (SELECT o.patient_id FROM drug_order d
      INNER JOIN orders o ON o.order_id = d.order_id
      WHERE d.drug_inventory_id IN(
        SELECT GROUP_CONCAT(DISTINCT(drug_id)
        ORDER BY drug_id ASC) FROM drug WHERE
        concept_id IN(SELECT concept_id FROM concept_name WHERE name IN('Isoniazid'))
      ) AND d.quantity > 0
      AND o.start_date = (SELECT MAX(start_date) FROM orders t WHERE t.patient_id = o.patient_id
      AND t.start_date BETWEEN DATE_FORMAT(DATE(my_start_date), '%Y-%m-%d 00:00:00')
      AND DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
      AND t.patient_id = my_patient_id
      ) GROUP BY o.patient_id);

  IF record_value IS NOT NULL THEN
    SET given = TRUE;
  END IF;


	RETURN given;
END;



DROP FUNCTION IF EXISTS `cohort_disaggregated_age_group`;

CREATE FUNCTION `cohort_disaggregated_age_group`(birthdate date, end_date date) RETURNS VARCHAR(15)
BEGIN

DECLARE age_in_months INT(11);
DECLARE age_in_years INT(11);
DECLARE age_group VARCHAR(15);

SET age_in_months = (SELECT timestampdiff(month, birthdate, end_date));
SET age_in_years  = (SELECT timestampdiff(year, birthdate, end_date));
SET age_group = ('Unknown');

IF age_in_months >= 0 AND age_in_months <= 5 THEN SET age_group = "0-5 months";
ELSEIF age_in_months > 5 AND age_in_months <= 11 THEN SET age_group = "6-11 months";
ELSEIF age_in_months > 11 AND age_in_months <= 23 THEN SET age_group = "12-23 months";
ELSEIF age_in_years >= 2 AND age_in_years <= 4 THEN SET age_group = "2-4 years";
ELSEIF age_in_years >= 5 AND age_in_years <= 9 THEN SET age_group = "5-9 years";
ELSEIF age_in_years >= 10 AND age_in_years <= 14 THEN SET age_group = "10-14 years";
ELSEIF age_in_years >= 15 AND age_in_years <= 17 THEN SET age_group = "15-17 years";
ELSEIF age_in_years >= 18 AND age_in_years <= 19 THEN SET age_group = "18-19 years";
ELSEIF age_in_years >= 20 AND age_in_years <= 24 THEN SET age_group = "20-24 years";
ELSEIF age_in_years >= 25 AND age_in_years <= 29 THEN SET age_group = "25-29 years";
ELSEIF age_in_years >= 30 AND age_in_years <= 34 THEN SET age_group = "30-34 years";
ELSEIF age_in_years >= 35 AND age_in_years <= 39 THEN SET age_group = "35-39 years";
ELSEIF age_in_years >= 40 AND age_in_years <= 44 THEN SET age_group = "40-44 years";
ELSEIF age_in_years >= 45 AND age_in_years <= 49 THEN SET age_group = "45-49 years";
ELSEIF age_in_years >= 50 THEN SET age_group = "50 plus years";
END IF;

RETURN age_group;
END;










DROP FUNCTION IF EXISTS `female_maternal_status`;

CREATE FUNCTION female_maternal_status(my_patient_id int, end_datetime datetime) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN

DECLARE breastfeeding_date DATETIME;
DECLARE pregnant_date DATETIME;
DECLARE maternal_status VARCHAR(20);
DECLARE obs_value_coded INT(11);


SET @reason_for_starting = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' LIMIT 1);

SET @pregnant_concepts := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name IN('Is patient pregnant?','Patient pregnant'));
SET @breastfeeding_concept := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name = 'Breastfeeding');

SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND        obs_datetime <= end_datetime);
SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id   AND obs_datetime <= end_datetime);

IF pregnant_date IS NULL THEN
  SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting AND voided = 0 AND person_id = my_patient_id AND      obs_datetime <= end_datetime AND value_coded IN(1755));
END IF;

IF breastfeeding_date IS NULL THEN
  SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime AND value_coded IN(834,5632));
END IF;

IF pregnant_date IS NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "FNP";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Unknown";
ELSEIF pregnant_date IS NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Check BF";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "Check FP";
END IF;

IF maternal_status = 'Unknown' THEN

  IF breastfeeding_date <= pregnant_date THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND        obs_datetime = pregnant_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;

  IF breastfeeding_date > pregnant_date THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND    obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;

  IF DATE(breastfeeding_date) = DATE(pregnant_date) AND maternal_status = 'FNP' THEN
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND    obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;
  END IF;
END IF;


IF maternal_status = 'Check FP' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND          obs_datetime = pregnant_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) AND voided = 0 AND person_id = my_patient_id AND        obs_datetime = pregnant_date);
    IF obs_value_coded IN(1755) THEN SET maternal_status = 'FP';
    END IF;
  END IF;

  IF maternal_status = 'Check FP' THEN SET maternal_status = 'FNP';
  END IF;
END IF;

IF maternal_status = 'Check BF' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND      obs_datetime = breastfeeding_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) AND voided = 0 AND person_id = my_patient_id AND        obs_datetime = breastfeeding_date);
    IF obs_value_coded IN(834,5632) THEN SET maternal_status = 'FBf';
    END IF;
  END IF;

  IF maternal_status = 'Check BF' THEN SET maternal_status = 'FNP';
  END IF;
END IF;



RETURN maternal_status;
END;



DROP FUNCTION IF EXISTS `patient_tb_status`;

CREATE FUNCTION `patient_tb_status`(my_patient_id INT, my_end_date DATE) RETURNS INT
BEGIN
	DECLARE screened INT DEFAULT FALSE;
	DECLARE tb_status INT;
  DECLARE tb_status_concept_id INT;

  SET tb_status_concept_id = (SELECT concept_id FROM concept_name
    WHERE name IN('TB status') AND voided = 0 LIMIT 1);

  SET tb_status = (SELECT ob.value_coded FROM obs ob
    INNER JOIN concept_name cn
    ON ob.value_coded = cn.concept_id
    WHERE ob.concept_id = tb_status_concept_id AND ob.voided = 0
    AND ob.obs_datetime = (
    SELECT MAX(t.obs_datetime) FROM obs t WHERE
    t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
    AND t.voided = 0 AND t.person_id = ob.person_id AND t.concept_id = tb_status_concept_id)
    AND ob.person_id = my_patient_id
    GROUP BY ob.person_id);

	RETURN tb_status;
END;



/* *************** */
/*
DROP FUNCTION IF EXISTS `patient_latest_adherence`;

CREATE FUNCTION `patient_latest_adherence`(my_patient_id INT, my_end_date DATE) RETURNS VARCHAR(100)
BEGIN
  DECLARE art_adherence_concept_id INT;
  DECLARE latest_obs_datetime TIMESTAMP;

  SET art_adherence_concept_id = (SELECT concept_id FROM concept_name
    WHERE name IN('What was the patients adherence for this drug order') AND voided = 0 LIMIT 1);

  SET latest_obs_datetime = (SELECT MAX(t.obs_datetime) FROM obs t
        INNER JOIN orders t2 ON t.order_id = t.order_id AND t2.voided = 0
        INNER JOIN drug_order t3 ON t3.order_id = t2.order_id
        INNER JOIN drug t4 ON t4.drug_id = t3.drug_inventory_id
        INNER JOIN concept_set t5 ON t5.concept_id = t4.concept_id
        WHERE t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
        AND t.concept_id = art_adherence_concept_id AND t.voided = 0
        AND t.person_id = my_patient_id AND t5.concept_set = 1085);

  IF latest_obs_datetime IS NULL THEN
    return null;
  END IF;

  SET @adherences := (SELECT GROUP_CONCAT(DISTINCT(ob.value_text) ORDER BY ob.value_text ASC) FROM obs ob
    INNER JOIN orders o ON o.order_id = ob.order_id AND o.voided = 0
    INNER JOIN drug_order od ON od.order_id = o.order_id
    INNER JOIN drug d ON d.drug_id = od.drug_inventory_id
    INNER JOIN concept_set s ON s.concept_id = d.concept_id
    WHERE s.concept_set = 1085 AND ob.voided = 0
    AND ob.concept_id = art_adherence_concept_id
    AND ob.obs_datetime = latest_obs_datetime
    AND ob.person_id = my_patient_id);


	RETURN @adherences;
END;

*/


DROP FUNCTION IF EXISTS `patient_has_side_effects`;

CREATE FUNCTION `patient_has_side_effects`(my_patient_id INT, my_end_date DATE) RETURNS VARCHAR(7)
BEGIN
  DECLARE mw_side_effects_concept_id INT;
  DECLARE yes_concept_id INT;
  DECLARE no_concept_id INT;
  DECLARE side_effect INT;
  DECLARE latest_obs_date DATE;

  SET mw_side_effects_concept_id = (SELECT concept_id FROM concept_name
    WHERE name IN('Malawi ART Side Effects') AND voided = 0 LIMIT 1);

  SET yes_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'YES' LIMIT 1);
  SET no_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'NO' LIMIT 1);

  SET latest_obs_date = (SELECT DATE(MAX(t.obs_datetime)) FROM obs t
        WHERE t.obs_datetime <= DATE_FORMAT(DATE(my_end_date), '%Y-%m-%d 23:59:59')
        AND t.concept_id = mw_side_effects_concept_id AND t.voided = 0
        AND t.person_id = my_patient_id);

  IF latest_obs_date IS NULL THEN
    return 'Unknown';
  END IF;



  SET side_effect = (SELECT value_coded FROM obs
      INNER JOIN temp_earliest_start_date e ON e.patient_id = obs.person_id
      WHERE obs_group_id IN (
      SELECT obs_id FROM obs
      WHERE concept_id = mw_side_effects_concept_id
        AND person_id = my_patient_id
        AND obs.obs_datetime BETWEEN DATE_FORMAT(DATE(latest_obs_date), '%Y-%m-%d 00:00:00')
        AND DATE_FORMAT(DATE(latest_obs_date), '%Y-%m-%d 23:59:59')
        AND DATE(obs_datetime) != DATE(e.date_enrolled)
      )GROUP BY concept_id HAVING value_coded = yes_concept_id LIMIT 1);

  IF side_effect IS NOT NULL THEN
    return 'Yes';
  END IF;


	RETURN 'No';
END;

DROP FUNCTION IF EXISTS `patient_who_stage`;

CREATE FUNCTION `patient_who_stage`(my_patient_id INT) RETURNS VARCHAR(50)
BEGIN
  DECLARE who_stage VARCHAR(255);
  DECLARE reason_concept_id INT;
  DECLARE coded_concept_id INT;
  DECLARE max_obs_datetime DATETIME;

  SET reason_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'WHO stage' AND voided = 0 LIMIT 1);
  SET max_obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0);
  SET coded_concept_id = (SELECT value_coded FROM obs WHERE person_id = my_patient_id AND concept_id = reason_concept_id AND voided = 0 AND obs_datetime = max_obs_datetime  LIMIT 1);
  SET who_stage = (SELECT name FROM concept_name WHERE concept_id = coded_concept_id AND LENGTH(name) > 0 LIMIT 1);

  RETURN who_stage;
END;


/* ----------------- PEPFAR PATIENT OUTCOME ------------------------ */
DROP FUNCTION IF EXISTS pepfar_patient_outcome;

CREATE FUNCTION `pepfar_patient_outcome`(patient_id INT, visit_date date) RETURNS varchar(25)
BEGIN
DECLARE set_program_id INT;
DECLARE set_patient_state INT;
DECLARE set_outcome varchar(25);
DECLARE set_date_started date;
DECLARE set_patient_state_died INT;
DECLARE set_died_concept_id INT;
DECLARE set_timestamp DATETIME;
DECLARE dispensed_quantity INT;

SET set_timestamp = TIMESTAMP(CONCAT(DATE(visit_date), ' ', '23:59:59'));
SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);

SET set_patient_state = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC LIMIT 1);

IF set_patient_state = 1 THEN
  SET set_patient_state = current_pepfar_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  ELSE
    SET set_outcome = 'Pre-ART (Continue)';
  END IF;
END IF;

IF set_patient_state = 2   THEN
  SET set_outcome = 'Patient transferred out';
END IF;

IF set_patient_state = 3 OR set_patient_state = 127 THEN
  SET set_outcome = 'Patient died';
END IF;

/* ............... This block of code checks if the patient has any state that is "died" */
IF set_patient_state != 3 AND set_patient_state != 127 THEN
  SET set_patient_state_died = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) AND state = 3 ORDER BY patient_state.patient_state_id DESC, patient_state.date_created DESC, start_date DESC LIMIT 1);

  SET set_died_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Patient died' LIMIT 1);

  IF set_patient_state_died IN(SELECT program_workflow_state_id FROM program_workflow_state WHERE concept_id = set_died_concept_id AND retired = 0) THEN
    SET set_outcome = 'Patient died';
    SET set_patient_state = 3;
  END IF;
END IF;
/* ....................  ends here .................... */


IF set_patient_state = 6 THEN
  SET set_outcome = 'Treatment stopped';
END IF;

IF set_patient_state = 7 OR set_outcome = 'Pre-ART (Continue)' OR set_outcome IS NULL THEN

  SET set_patient_state = current_pepfar_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_patient_state = 0 OR set_outcome IS NULL THEN

    SET dispensed_quantity = (SELECT d.quantity
      FROM orders o
      INNER JOIN drug_order d ON d.order_id = o.order_id
      INNER JOIN drug ON drug.drug_id = d.drug_inventory_id
      WHERE o.patient_id = patient_id AND d.drug_inventory_id IN(
        SELECT DISTINCT(drug_id) FROM drug WHERE
        concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = 1085)
    ) AND DATE(o.start_date) <= visit_date AND d.quantity > 0 ORDER BY start_date DESC LIMIT 1);

    IF dispensed_quantity > 0 THEN
      SET set_outcome = 'On antiretrovirals';
    END IF;
  END IF;
END IF;

IF set_outcome IS NULL THEN
  SET set_patient_state = current_pepfar_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_outcome IS NULL THEN
    SET set_outcome = 'Unknown';
  END IF;

END IF;

RETURN set_outcome;
END;
