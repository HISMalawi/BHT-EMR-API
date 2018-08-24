/*
Purpose			: Retrieve all patients that have multiple HIV Programs
Date			: 06 Jan 2016
Created by		: Precious Ulemu Bondwe
Modifications	:




*/

SELECT 
    pp.patient_id AS 'Patient ID',
    pn.given_name AS 'First Name',
    pn.family_name AS 'Surname',
    pi.identifier AS 'ARV Number',
    COUNT(pp.patient_id) AS 'Occurence'
FROM
    patient_program pp
        LEFT JOIN
    person_name pn ON pp.patient_id = pn.person_id
        LEFT JOIN
    patient_identifier pi ON pp.patient_id = pi.patient_id
        AND pi.identifier_type = 4
WHERE
    pp.program_id = 1 AND pp.voided = 0
        AND pp.patient_id IN (SELECT 
            patient_id
        FROM
            earliest_start_date)
GROUP BY pp.patient_id
HAVING occurence > 1
ORDER BY pp.patient_id ASC;

