select p.person_id,
(select property_value site_id from global_property where property='current_health_center_id') site_id,
pn.given_name,pn.middle_name,pn.family_name,
p.gender sex,
p.birthdate, case when p.birthdate_estimated =1 then 'Yes' else 'No' end birthdate_est,pa.region region_of_origin, pa.address2 home_district,
pa.county_district home_traditional_authority,pa.neighborhood_cell  home_village,pa.region,pa.state_province current_district,pa.township_division current_traditional_authority,
pa.city_village current_village, paa.value closest_landmark,GROUP_CONCAT(pi2.identifier) national_id
from person p
join patient_program pp on p.person_id = pp.patient_id and pp.program_id = 1 and p.voided=0 and pp.voided = 0
left join person_name pn on p.person_id=pn.person_id  and pn.voided=0  
left join person_address pa on p.person_id =pa.person_id and pa.voided=0
LEFT JOIN person_attribute paa on p.person_id=paa.person_id  and paa.voided=0 and  paa.person_attribute_type_id = 19
left join patient_identifier pi2 on p.person_id=pi2.patient_id and pi2.identifier_type=28 and pi2.voided=0
WHERE p.person_id = @person_id
group by p.person_id;
