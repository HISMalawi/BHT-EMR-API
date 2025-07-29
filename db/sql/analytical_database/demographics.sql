with cellphone_number as
(
select
	person_id as person_id,
	coalesce(max((case when (person_attribute_type_id = 12) then value end)),
	max((case when (person_attribute_type_id = 14) then value end)),
	max((case when (person_attribute_type_id = 15) then value end))) as cellphone_number
from
	person_attribute
where
	(person_attribute.voided = 0)
group by
	person_attribute.person_id)
select
	p.person_id,
	(
	select
		property_value site_id
	from
		global_property
	where
		property = 'current_health_center_id') site_id,
	pn.given_name,
	pn.middle_name,
	pn.family_name,
	p.gender sex,
	p.birthdate,
	case
		when p.birthdate_estimated = 1 then 'Yes'
		else 'Yes'
	end birthdate_est,
	cellphone_number,
	pa.region region_of_origin,
	pa.address2 home_district,
	pa.county_district home_traditional_authority,
	pa.neighborhood_cell home_village,
	pa.region,
	pa.state_province current_district,
	pa.township_division current_traditional_authority,
	pa.city_village current_village,
	paa.value closest_landmark,
	group_concat(distinct pi2.identifier) national_id
from
	person p
join patient_program pp on
	p.person_id = pp.patient_id
	and pp.program_id = 1
	and p.voided = 0
	and pp.voided = 0
  and pp.patient_id = @person_id
left join person_name pn on
	p.person_id = pn.person_id
	and pn.voided = 0
  and pn.person_id = @person_id
left join person_address pa on
	p.person_id = pa.person_id
	and pa.voided = 0
  and pa.person_id = @person_id
left join person_attribute paa on
	p.person_id = paa.person_id
	and paa.voided = 0
	and paa.person_attribute_type_id = 19
  and paa.person_id = @person_id
left join cellphone_number on
	p.person_id = cellphone_number.person_id
left join patient_identifier pi2 on
	p.person_id = pi2.patient_id
	and pi2.identifier_type = 28
	and pi2.voided = 0
  and pi2.patient_id = @person_id
