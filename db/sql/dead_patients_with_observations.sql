
/* Updating patients with visits after death */

UPDATE person SET death_date = NULL, dead = 0 
WHERE person_id IN (SELECT DISTINCT(e.patient_id) FROM earliest_start_date e 
INNER JOIN obs o ON o.person_id = e.patient_id
WHERE e.death_date IS NOT NULL 
AND o.voided = 0
AND DATE(o.obs_datetime) > DATE(e.death_date));

