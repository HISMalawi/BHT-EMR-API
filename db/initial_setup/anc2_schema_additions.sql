
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

-- gets all lmp observations
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `last_menstraul_period_date` AS
  SELECT `person_id`, `encounter_id`, `value_datetime` AS `lmp`, `obs_datetime`, `date_created`
  FROM `obs`
  WHERE `concept_id` = 968
  AND `voided` = 0
  ORDER BY `person_id`, `obs_datetime` DESC;


-- ANC visit encounter_type with reason for visit/ type of visit observations
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `anc_visit_observations` AS
  SELECT `person_id`, `e`.`encounter_id`, `o`.`value_numeric`, `e`.`encounter_datetime`
  FROM `encounter` `e`
    INNER JOIN `obs` `o` ON `o`.`encounter_id` = `e`.`encounter_id` AND `e`.`encounter_type` = 107 AND `o`.`concept_id` = 6189
  WHERE `o`.`voided` = 0 AND `e`.`voided` = 0
  ORDER BY `o`.`person_id`, `e`.`encounter_datetime` DESC;


-- pulling all HIV status and HIV test date observations
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `hiv_status_obs` AS
  SELECT `o`.`person_id`, `o`.`encounter_id`, IFNULL(`o`.`value_coded`, `o`.`value_text`) AS `hiv_status`,`o`.`obs_datetime`
  FROM `obs` `o`
  WHERE `o`.`concept_id` IN (3753)
  AND `o`.`voided` = 0
  ORDER BY `o`.`person_id`, `o`.`obs_datetime` DESC;

-- pulling all HIV test date observations
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `hiv_test_date_obs` AS
   SELECT `obs`.`person_id`, `obs`.`encounter_id`, IFNULL(`obs`.`value_datetime`, `obs`.`value_text`) AS `hiv_test_date`, `obs`.`obs_datetime`
	 FROM `obs` `obs`
   WHERE `obs`.`concept_id` = 1837
   AND `obs`.`voided` = 0
   ORDER BY `obs`.`person_id`, `obs`.`obs_datetime` DESC;


-- pulling all patients with hiv_status and hiv_test_date observations
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
VIEW `hiv_test_and_hiv_test_date_obs` AS
SELECT
    `hs`.`person_id`,
    `hs`.`encounter_id`,
    `hs`.`hiv_status`,
    `ht`.`hiv_test_date`,
    `ht`.`obs_datetime`
FROM
    `hiv_status_obs` `hs`
        LEFT JOIN
    `hiv_test_date_obs` `ht` ON `hs`.`person_id` = `ht`.`person_id`
        AND `hs`.`encounter_id` = `ht`.`encounter_id`
        AND DATE(`hs`.`obs_datetime`) = DATE(`ht`.`obs_datetime`)
ORDER BY `ht`.`person_id`, `ht`.`obs_datetime` DESC;

DROP FUNCTION IF EXISTS max_patient_lmp;

DELIMITER $$
CREATE FUNCTION max_patient_lmp(my_patient_id INT, my_e_date DATE, my_min_date DATE) RETURNS DATE
BEGIN

DECLARE lmp_date DATE;

SET lmp_date = (SELECT DATE(MAX(lmp)) FROM last_menstraul_period_date
                WHERE DATE(obs_datetime) <= my_e_date
                AND DATE(obs_datetime) >= my_min_date
                AND person_id = my_patient_id);

RETURN lmp_date;
END$$
DELIMITER ;



DROP FUNCTION IF EXISTS max_anc_visit_obs;

DELIMITER $$
CREATE FUNCTION max_anc_visit_obs(my_patient_id INT, my_e_date DATE, my_min_date DATE) RETURNS INT(11)
BEGIN

DECLARE visits INT;

SET visits = (SELECT MAX(a.value_numeric) FROM anc_visit_observations a
                WHERE DATE(encounter_datetime) <= my_e_date
                AND DATE(encounter_datetime) >= my_min_date
                AND person_id = my_patient_id);

RETURN visits;
END$$
DELIMITER ;

--
--
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
