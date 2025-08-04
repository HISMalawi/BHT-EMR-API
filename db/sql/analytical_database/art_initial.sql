with date_drug as
(
select
	e.patient_id,
	date(o.value_datetime) as date_drug_received_from_previous_facility
from
	encounter e
join obs
o on
	e.encounter_id = o.encounter_id
where
	e.encounter_type = 53
	and e.voided = 0
	and e.program_id = 1
	and o.concept_id = 10564
    and e.patient_id = @patient_id
group by
	e.patient_id
),
drugs_quantity as
(
select
	e.patient_id,
	group_concat(concat(d.name, ' ', o.value_numeric) separator ' || ') as drug_received_from_previous_facility,
			(
	select
		property_value
	from
		global_property gp
	where
		lower(property) = 'current_health_center_id') as site_id
from
	encounter e
join obs o on
	e.encounter_id = o.encounter_id
join drug d on
	o.value_drug = d.drug_id
where
	e.program_id = 1
	and e.voided = 0
	and o.voided = 0
	and o.concept_id in (10563)
		and e.encounter_type = 53
		and o.value_numeric <> 0
        and e.patient_id = @patient_id
    group by
		e.patient_id
),
regimen_from_prev_fac as
(with regimen_meta as (
select
	group_concat(d.drug_id order by d.drug_id) as drugs,
	rn.name as regimen_name
from
	moh_regimen_combination mc
join moh_regimen_combination_drug d
    on
	mc.regimen_combination_id = d.regimen_combination_id
join moh_regimen_name rn
    on
	mc.regimen_name_id = rn.regimen_name_id
group by
	mc.regimen_combination_id
),
patient_drugs as (
select
	e.patient_id,
	group_concat(d.drug_id order by d.drug_id) as drugs,
	(
	select
		gp.property_value
	from
		global_property gp
	where
		lower(gp.property) = 'current_health_center_id'
    ) as site_id
from
	encounter e
join obs o on
	e.encounter_id = o.encounter_id
join drug d on
	o.value_drug = d.drug_id
where
	e.program_id = 1
	and e.voided = 0
	and o.voided = 0
	and o.concept_id = 10563
	and e.encounter_type = 53
    and e.patient_id = @patient_id
group by
	e.patient_id
)
select
	p.patient_id,
	case
		when m.regimen_name is null then 'Unknown'
		else m.regimen_name
	end as regimen_name,
	p.site_id
from
	patient_drugs p
left join regimen_meta m
  on
	p.drugs = m.drugs),
other_stage_defining_conditions as
(
select
	e.patient_id,
	date(e.encounter_datetime) as visit_date,
	group_concat(distinct value_coded.name) as other_stage_defining_conditions,
		(
	select
		property_value
	from
		global_property gp
	where
		lower(property) = 'current_health_center_id') as site_id
from
	encounter e
join obs o on
	e.encounter_id = o.encounter_id
join concept_name concept_id on
	o.concept_id = concept_id.concept_id
join concept_name value_coded on
	o.value_coded = value_coded.concept_id
where
	e.encounter_type = 52
	and e.voided = 0
	and o.voided = 0
	and lower(concept_id.name) regexp 'who'
		and value_coded.voided = 0
		and value_coded.concept_name_type = 'FULLY_SPECIFIED'
        and e.patient_id = @patient_id
	group by
		e.patient_id
),
cd4_percent as (
select
	e.patient_id,
	date(e.encounter_datetime) as visit_date,
	coalesce(o.value_coded, o.value_numeric, o.value_text) as cd4_percent,
		(
	select
		property_value
	from
		global_property gp
	where
		lower(property) = 'current_health_center_id') as site_id
from
	encounter e
join obs o on
	e.encounter_id = o.encounter_id
where
	e.voided = 0
	and o.voided = 0
	and o.concept_id = 730
    and e.patient_id = @patient_id
)
select
	p.person_id as patient_id,
	(
	select
		property_value
	from
		global_property
	where
		property = 'current_health_center_id') as site_id,
	max(if(o.concept_id = 3289, cn2.name, null)) as type_of_patient,
	max(if(pi.identifier_type = 4 and pi.voided = 0, pi.identifier, null)) as arv_number,
	max(if(o.concept_id = 2552, cn2.name, null)) as agrees_to_follow_up,
	max(if(o.concept_id = 7879, coalesce(o.value_numeric, o.value_text), null)) as hts_linkage_number,
	max(if(o.concept_id = 7754, cn2.name, null)) as ever_received_arvs,
	max(if(o.concept_id = 7880, cn2.name, null)) as confirmatory_hiv_test,
	max(if(o.concept_id = 7881, o.value_text, null)) as location_of_confirmatory_hiv_test,
	max(if(o.concept_id = 7882, cast(o.value_datetime as date), null)) as confirmatory_hiv_test_date,
	max(if(o.concept_id = 7882, 
        case when o.value_datetime is not null and o.value_text = 'Estimated' then 'Yes' 
             when o.value_datetime is not null and o.value_text is null then 'No' 
             else '' end, 
       '' )) as confirmatory_hiv_test_date_est,
	max(if(o.concept_id = 7751, cast(o.value_datetime as date), null)) as last_taken_arvs_date,
	max(if(o.concept_id = 7751, 
        case when o.value_datetime is not null and o.value_text = 'Estimated' then 'Yes' 
             when o.value_datetime is not null and o.value_text is null then 'No' 
             else '' end, 
      '' )) as last_taken_arvs_date_est,
	max(if(o.concept_id = 7752, cn2.name, null)) as taken_arvs_in_the_last_two_months,
	max(if(o.concept_id = 6394, cn2.name, null)) as taken_arvs_in_the_last_two_weeks,
	max(if(o.concept_id = 7937, cn2.name, null)) as ever_registered_at_an_art_clinic,
	max(if(o.concept_id = 7750, o.value_text, null)) as location_of_art_initiation,
	coalesce(
        max(if(o.concept_id = 2516, cast(o.value_datetime as date), null)),
        cast(date_antiretrovirals_started(p.person_id, min(ps.start_date)) as date)
    ) as art_start_date,
	case
		when max(if(o.concept_id = 2516, o.value_datetime, null)) is null
		or patient_date_enrolled(p.person_id) is null then ''
		else timestampdiff(month, 
            date(max(if(o.concept_id = 2516, o.value_datetime, null))), 
            date(patient_date_enrolled(p.person_id)))
	end as months_on_art,
	timestampdiff(year, pe.birthdate, min(ps.start_date)) as age_at_initiation,
	timestampdiff(day, pe.birthdate, min(ps.start_date)) as age_in_days_at_initiation,
	max(if(o.concept_id = 6981, o.value_text, null)) as art_number_at_previous_location,
	max(if(o.concept_id = 7972, cn2.name, null)) as patient_pregnant,
	max(if(o.concept_id = 5632, cn2.name, null)) as patient_breastfeeding,
	max(if(o.concept_id = 7562, cn2.name, null)) as who_stage,
	max(if(o.concept_id = 7563, cn2.name, null)) as reason_for_starting,
	max(if(o.concept_id = 5497, concat('', o.value_modifier, o.value_numeric), null)) as cd4_count,
	date_drug.date_drug_received_from_previous_facility,
	drugs_quantity.drug_received_from_previous_facility,
	regimen_from_prev_fac.regimen_name as regimen_category_at_previous_facility,
	other_stage_defining_conditions.other_stage_defining_conditions,
	cd4_percent.cd4_percent,
	cast(patient_date_enrolled(p.person_id) as date) as date_enrolled_at_facility
from
	person p
left join 
    patient_program pp on
	p.person_id = pp.patient_id
	and pp.program_id = 1
	and pp.voided = 0
    and pp.patient_id = @patient_id
left join 
    patient_state ps on
	pp.patient_program_id = ps.patient_program_id
	and ps.voided = 0
	and date(ps.start_date) >= 1900-01-01
left join 
    encounter e on
	p.person_id = e.patient_id
	and e.encounter_type in (9, 5, 52, 53)
	and e.voided = 0
    and e.patient_id = @patient_id
left join 
    obs o on
	e.encounter_id = o.encounter_id
	and o.voided = 0
	and o.concept_id in (
        7754, 7880, 7881, 7882, 7751, 6394, 7752, 7937, 7750, 2516, 
        6981, 7879, 6393, 5497, 3289, 2552, 7972, 5632, 7562, 7563
    )
left join 
    concept_name cn on
	o.concept_id = cn.concept_id
	and cn.locale = 'en'
	and cn.voided = 0
	and cn.concept_name_type = 'FULLY_SPECIFIED'
left join 
    concept_name cn2 on
	o.value_coded = cn2.concept_id
	and cn2.locale = 'en'
	and cn2.voided = 0
	and cn2.concept_name_type = 'FULLY_SPECIFIED'
left join 
    patient_identifier pi on
	p.person_id = pi.patient_id
	and pi.identifier_type = 4
	and pi.voided = 0
    and pi.patient_id = @patient_id
left join 
    person pe on
	p.person_id = pe.person_id
    and pe.person_id = @patient_id
left join date_drug on
	p.person_id = date_drug.patient_id
left join drugs_quantity on
	p.person_id = drugs_quantity.patient_id
left join other_stage_defining_conditions on
	p.person_id = other_stage_defining_conditions.patient_id
left join cd4_percent on
	p.person_id = cd4_percent.patient_id
left join regimen_from_prev_fac on
	p.person_id = regimen_from_prev_fac.patient_id
where
	patient_date_enrolled(p.person_id) is not null
	and p.person_id = @patient_id
group by
	p.person_id;