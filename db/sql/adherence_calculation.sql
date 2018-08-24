DROP FUNCTION IF EXISTS adherence_cal;                                          
                                                                                
DELIMITER $$                                                                     
CREATE FUNCTION adherence_cal(patient_id INT, drug_id INT , visit_date varchar(10)) RETURNS INT
BEGIN                                                                           
                                                                                
DECLARE given_last_time INT;                                                        
DECLARE adherence INT;                                                          
DECLARE dose DOUBLE;                                                          
DECLARE days_gone INT;                                                          
DECLARE amount_remaining DOUBLE;                                                          
DECLARE expected_remaining DOUBLE;                                                          
DECLARE amount_dispensed_concept_id INT;
DECLARE amount_brought_concept_id INT;

SET amount_dispensed_concept_id = (SELECT concept_id FROM concept_name WHERE name ="AMOUNT DISPENSED" LIMIT 1);
SET amount_brought_concept_id = (SELECT concept_id FROM concept_name WHERE name ="AMOUNT OF DRUG BROUGHT TO CLINIC" LIMIT 1);
                                                                                
SET given_last_time = (SELECT quantity FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id AND t1.drug_inventory_id = drug_id WHERE t3.concept_id = amount_dispensed_concept_id AND t3.person_id = patient_id AND obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE t3.obs_id=obs_id AND voided=0 AND obs_datetime < DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 00:00:00')) ORDER BY obs_datetime DESC LIMIT 1);


SET days_gone = (SELECT DATEDIFF(DATE(visit_date),DATE(obs_datetime)) FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id AND t1.drug_inventory_id = drug_id WHERE t3.concept_id = amount_dispensed_concept_id AND t3.person_id = patient_id AND obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE t3.obs_id=obs_id AND voided=0 AND obs_datetime < DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 00:00:00')) ORDER BY obs_datetime DESC LIMIT 1);


SET dose = (SELECT equivalent_daily_dose FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id AND t1.drug_inventory_id = drug_id WHERE t3.concept_id = amount_dispensed_concept_id AND t3.person_id = patient_id AND obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE t3.obs_id=obs_id AND voided=0 AND obs_datetime < DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 00:00:00')) ORDER BY obs_datetime DESC LIMIT 1);

SET expected_remaining = (SELECT quantity - ((DATEDIFF(DATE(visit_date),DATE(obs_datetime))) * equivalent_daily_dose) FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id AND t1.drug_inventory_id = drug_id WHERE t3.concept_id = amount_dispensed_concept_id AND t3.person_id = patient_id AND obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE t3.obs_id=obs_id AND voided=0 AND obs_datetime < DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 00:00:00')) ORDER BY obs_datetime DESC LIMIT 1);

SET amount_remaining = (SELECT value_numeric FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id AND t1.drug_inventory_id = drug_id WHERE t3.concept_id = amount_brought_concept_id AND t3.person_id = patient_id AND obs_datetime = (SELECT MAX(obs_datetime) FROM obs WHERE t3.obs_id=obs_id AND voided=0 AND obs_datetime >= DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 00:00:00') AND obs_datetime <= DATE_FORMAT(DATE(visit_date), '%Y-%m-%d 23:59:59')) ORDER BY obs_datetime DESC LIMIT 1);

SET adherence = ROUND((100*(given_last_time - amount_remaining) / (given_last_time - expected_remaining)));

RETURN adherence;
END$$                                                                           
DELIMITER ;

