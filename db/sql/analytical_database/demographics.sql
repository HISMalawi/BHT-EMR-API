WITH cellphone_number AS
(
SELECT
	person_id,
	COALESCE(
		MAX(CASE WHEN person_attribute_type_id = 12 THEN value END),
		MAX(CASE WHEN person_attribute_type_id = 14 THEN value END),
		MAX(CASE WHEN person_attribute_type_id = 15 THEN value END)
	) AS cellphone_number
FROM
	person_attribute
WHERE
	voided = 0
	AND person_id = @person_id
GROUP BY
	person_id
)
SELECT
	p.person_id,
	(
	SELECT
		property_value
	FROM
		global_property
	WHERE
		property = 'current_health_center_id'
	) AS site_id,
	MAX(pn.given_name) AS given_name,
	MAX(pn.middle_name) AS middle_name,
	MAX(pn.family_name) AS family_name,
	CASE
		WHEN UPPER(p.gender) IN ('M', 'MALE') THEN 'M'
		WHEN UPPER(p.gender) IN ('F', 'FEMALE') THEN 'F'
		ELSE 'Unknown'
	END AS sex,
	CASE
		WHEN YEAR(p.birthdate) < 1900 THEN '1900-01-01'
		ELSE p.birthdate
	END AS birthdate,
	CASE
		WHEN p.birthdate_estimated = 1 THEN 'Yes'
		ELSE 'Yes'
	END AS birthdate_est,
	c.cellphone_number,
	CASE
		WHEN MAX(pa.region) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.region)
	END AS region_of_origin,
	CASE
		WHEN MAX(pa.address2) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.address2)
	END AS home_district,
	CASE
		WHEN MAX(pa.county_district) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.county_district)
	END AS home_traditional_authority,
	CASE
		WHEN MAX(pa.neighborhood_cell) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.neighborhood_cell)
	END AS home_village,
	CASE
		WHEN MAX(pa.region) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.region)
	END AS region,
	CASE
		WHEN MAX(pa.state_province) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.state_province)
	END AS current_district,
	CASE
		WHEN MAX(pa.township_division) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.township_division)
	END AS current_traditional_authority,
	CASE
		WHEN MAX(pa.city_village) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(pa.city_village)
	END AS current_village,
	CASE
		WHEN MAX(paa.value) LIKE CONCAT('%', CHAR(0), '%') THEN NULL
		ELSE MAX(paa.value)
	END AS closest_landmark,
	GROUP_CONCAT(DISTINCT pi2.identifier) AS national_id
FROM
	person p
LEFT JOIN patient_program pp
    ON
	p.person_id = pp.patient_id
	AND pp.program_id = 1
	AND pp.voided = 0
    AND p.person_id = @person_id
LEFT JOIN person_name pn
    ON
	p.person_id = pn.person_id
	AND pn.voided = 0
    AND p.person_id = @person_id
LEFT JOIN person_address pa
    ON
	p.person_id = pa.person_id
	AND pa.voided = 0
    AND p.person_id = @person_id
LEFT JOIN person_attribute paa
    ON
	p.person_id = paa.person_id
	AND paa.voided = 0
	AND paa.person_attribute_type_id = 19
    AND p.person_id = @person_id
LEFT JOIN cellphone_number c
    ON
	p.person_id = c.person_id
    AND p.person_id = @person_id
LEFT JOIN patient_identifier pi2
    ON
	p.person_id = pi2.patient_id
	AND pi2.identifier_type = 28
	AND pi2.voided = 0
    AND p.person_id = @person_id
WHERE
	p.voided = 0
    AND p.person_id = @person_id
GROUP BY
	p.person_id;