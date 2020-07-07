
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

/* Current regimen query */
DROP FUNCTION IF EXISTS `new_patient_current_regimen`;
DELIMITER ;;
CREATE FUNCTION `new_patient_current_regimen`(`my_patient_id` INT, `my_date` DATE) RETURNS VARCHAR(10)
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
/*
  IF regimen IS NULL THEN
    regimen = 'N/A';
  END;
*/
  RETURN regimen;
END;;

TRUNCATE moh_regimen_combination_drug;
TRUNCATE moh_regimen_combination;
TRUNCATE moh_regimen_name;

/* Populate tables */
INSERT INTO moh_regimen_name (regimen_name_id, name)
VALUES (1, '0P'),
       (2, '2P'),
       (3, '4P'),
       (4, '9P'),
       (5, '11P'),
       (6, '14P'),
       (7, '15P'),
       (8, '16P'),
       (9, '17P'),
       (10, '0A'),
       (11, '2A'),
       (12, '4A'),
       (13, '5A'),
       (14, '6A'),
       (15, '7A'),
       (16, '8A'),
       (17, '9A'),
       (18, '10A'),
       (19, '11A'),
       (20, '12A'),
       (21, '13A'),
       (22, '14A'),
       (23, '15A'),
       (24, '16A'),
       (25, '17A'),
       (26, '1P'),
       (27, '1A'),
       (28, '3P'),
       (29, 'Other');

/* Regimen 0P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (1, 1), (2, 1), (3, 1), (4, 1), (5, 1);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (1, 733), (1, 968),
       (2, 22), (2, 733),
       (3, 969), (3, 968),
       (4, 968), (4, 1044),
       (5, 22), (5, 1044);

/* Regimen 0A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (6, 10);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (6, 22), (6, 969);

/* Regimen 1A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (7, 27);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (7, 613);

/* Regimen 1P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (8, 26);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (8, 72);

/* Regimen 2P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (9, 2);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (9, 732);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (10, 2);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (10, 732), (10, 736);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (11, 2);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (11, 732), (11, 39);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (12, 2);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (12, 731), (12, 736);

/* Regimen 2A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (13, 11);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (13, 731);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (14, 11);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (14, 731), (14, 39);

/* Regimen 3P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (15, 28);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (15, 955);

/* Regimen 4P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (16, 3);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (16, 30), (16, 736);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (17, 3);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (17, 11), (17, 736);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (18, 3);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (18, 30), (18, 39);

/* Regimen 4A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (19, 12);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (19, 11), (19, 39);

/* Regimen 5A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (20, 13);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (20, 735);

/* Regimen 6A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (21, 14);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (21, 22), (21, 734);

/* Regimen 7A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (22, 15);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (22, 932), (22, 734);

/* Regimen 8A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (23, 16);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (23, 932), (23, 39);

/* Regimen 9P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (24, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (24, 74), (24, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (25, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (25, 73), (25, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (26, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (26, 733), (26, 979);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (27, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (27, 74), (27, 969);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (28, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (28, 969), (28, 979);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (29, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (29, 74), (29, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (30, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (30, 73), (30, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (31, 4);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (31, 979), (31, 1044);

/* Regimen 9A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (32, 17);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (32, 73), (32, 969);

/* Regimen 10A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (33, 18);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (33, 73), (33, 734);

/* Regimen 11P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (34, 5);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (34, 74), (34, 736);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (35, 5);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (35, 73), (35, 736);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (36, 5);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (36, 39), (36, 74);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (37, 5);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (37, 736), (37, 979);

/* Regimen 11A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (38, 19);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (38, 39), (38, 73);

/* Regimen 12A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (39, 20);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (39, 976), (39, 977), (39, 982);

/* Regimen 13A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (40, 21);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (40, 983);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (41, 21);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (41, 734), (41, 982);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (42, 21);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (42, 982), (42, 983);

/* Regimen 14A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (43, 22);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (43, 982), (43, 984);

/* Regimen 14P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (44, 6);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (44, 736), (44, 969);

/* Regimen 15A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (45, 23);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (45, 982), (45, 969);

/* Regimen 15P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (46, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (46, 982), (46, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (47, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (47, 981), (47, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (48, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (48, 980), (48, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (49, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (49, 982), (49, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (50, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (50, 981), (50, 981);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (51, 7);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (51, 980), (51, 980);

/* Regimen 16A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (52, 24);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (52, 954), (52, 969);

/* Regimen 16P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (53, 8);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (53, 1043), (53, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (54, 8);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (54, 954), (54, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (55, 8);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (55, 954), (55, 733);

/* Regimen 17A */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (56, 25);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (56, 11), (56, 969);

/* Regimen 17P */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (57, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (57, 30), (57, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (58, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (58, 30), (58, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (59, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (59, 733), (59, 954);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (60, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (60, 29), (60, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (61, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (61, 28), (61, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (62, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (62, 11), (62, 733);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (63, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (63, 29), (63, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (64, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (64, 24), (64, 1044);

INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (65, 9);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (65, 11), (65, 1044);

/* Regimen Other */
INSERT INTO moh_regimen_combination (regimen_combination_id, regimen_name_id)
VALUES (66, 29);

INSERT INTO moh_regimen_combination_drug (regimen_combination_id, drug_id)
VALUES (66, 1046);
