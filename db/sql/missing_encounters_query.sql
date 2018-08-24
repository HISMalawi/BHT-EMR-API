SELECT b1e.encounter_id, b1e.patient_id, b1e.encounter_datetime,
				b1e.encounter_type
	FROM bart1.encounter b1e LEFT JOIN bart2.encounter b2e ON b2e.encounter_type = 54
							AND b1e.patient_id = b2e.patient_id AND
							DATE(b1e.encounter_datetime) = DATE(b2e.encounter_datetime)
	WHERE b1e.encounter_type = 3
	AND b2e.patient_id IS NULL;
