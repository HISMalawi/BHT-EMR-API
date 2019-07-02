drop table if exists ANC_patients_migrated;

create table ANC_patients_migrated as 
select ANC_patient_id from ANC_only_patients_details
union
select ANC_patient_id from ANC_patient_details
union
select ANC_patient_id from anc_remaining_diff_gender
union
select ANC_patient_id from anc_art_patients_with_voided_art_identifier;


select pi.patient_id, pn.family_name, pn.given_name, pi.identifier, p.gender, p.birthdate from patient_identifier pi
 inner join person_name pn on pn.person_id = pi.patient_id
 inner join person p on p.person_id = pi.patient_id
where pi.identifier_type = 3 and pi.voided = 0 and pi.patient_id not in (select ANC_patient_id from ANC_patients_migrated);
