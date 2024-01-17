LOCK TABLES `task` WRITE;
/*!40000 ALTER TABLE `task` DISABLE KEYS*/;

INSERT INTO `task` (url,encounter_type,
description,
location,
gender,
has_obs_concept_id,
has_obs_value_coded,
has_obs_value_drug,
has_obs_value_datetime,
has_obs_value_numeric,
has_obs_value_text,
has_obs_scope,
has_program_id,
has_program_workflow_state_id,
has_identifier_type_id,
has_relationship_type_id,
has_order_type_id,
has_encounter_type_today,
skip_if_has,
sort_weight,
creator,
date_created,
voided,
voided_by,
date_voided,
void_reason,
changed_by,
date_changed,
uuid
) VALUES ('/encounters/new/art_initial?show&patient_id={patient}','ART_INITIAL','NotenrolledinHIVprogramn','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,1,1,1,'2010-02-2611:25:51',0,NULL,NULL,NULL,1,'2010-02-2611:25:51','eeba2f84-22b8-11df-b344-0026181bb84d'),('/encounters/new/hiv_reception?show&patient_id={patient}','HIVRECEPTION','Always','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,3,1,'2010-02-2611:47:13',0,NULL,NULL,NULL,1,'2010-02-2611:47:13','ea6de076-22bb-11df-b344-0026181bb84d'),('/encounters/new/vitals?patient_id={patient}','VITALS','PATIENT_PRESENT=YES','Retrospective',NULL,1805,1065,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,4,1,'2010-02-2613:45:50',0,NULL,NULL,NULL,1,'2010-02-2613:45:50','7cc4fc2e-22cc-11df-b344-0026181bb84d'),('/encounters/new/hiv_staging?show&patient_id={patient}','HIVSTAGING','EVERRECEIVEDART=YES','Retrospective',NULL,7754,1065,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,2,1,'2010-02-2613:45:50',0,NULL,NULL,NULL,1,'2010-02-2613:45:50','7cc4fc2e-22cc-11df-b344-0026181bb84d'),('/patients/show/{patient}',NULL,'EIDpatientsgostraighttoDashboardfornow','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',4,NULL,NULL,NULL,NULL,NULL,0,0,1,'2011-04-3000:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/patients/show/{patient}',NULL,'StophereifARTELIGIBILITY=UNKNOWN','Retrospective',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,98,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/patients/show/{patient}',NULL,'IfTREATMENTtoday','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,'TREATMENT',0,99,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/art_visit?show&patient_id={patient}','ARTVISIT','InstateOnART','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,0,2,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/art_adherence?show&patient_id={patient}','ARTADHERENCE','ARTADHERENCE','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ARTVISIT',0,3,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,1,'2011-03-0815:59:44',NULL),('/regimens/new?patient_id={patient}','TREATMENT','IfARTVisittodayANDREFERTOARTCLINICIAN=NO','Retrospective',NULL,6969,1066,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ARTVISIT',0,4,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/patients/show/{patient}','TREATMENT','IfARTVisittodayANDREFERTOARTCLINICIAN=YES','Retrospective',NULL,6969,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ARTVISIT',0,5,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/appointment?patient_id={patient}','APPOINTMENT','IfDISPENSEtoday','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,'DISPENSE',0,7,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/hiv_staging?show&patient_id={patient}','HIVSTAGING','NotinstateOnART','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,1,1,1,'2010-02-2614:00:23',0,NULL,NULL,NULL,1,'2010-02-2614:00:23','84dd80dc-22ce-11df-b344-0026181bb84d'),('/patients/show/{patient}',NULL,'ARTELIGIBILITY=UNKNOWN','Retrospective',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,97,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/art_visit?show&patient_id={patient}','ARTVISIT','NOTARTELIGIBILITY=UNKNOWN','Retrospective',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,1,3,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/regimens/new?patient_id={patient}','TREATMENT','ARTVISITtoday','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ARTVISIT',0,5,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/encounters/new/art_visit?show&patient_id={patient}',NULL,'REFERTOCLINICIAN=YES','Retrospective',NULL,6969,1065,NULL,NULL,NULL,NULL,'RECENT',NULL,NULL,NULL,NULL,NULL,NULL,0,4,1,'2011-01-1300:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/patients/show/{patient}',NULL,'EIDpatientsgostraighttoDashboardfornow','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',4,NULL,NULL,NULL,NULL,NULL,0,0,1,'2011-04-3000:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),('/patients/treatment/{patient}','DISPENSING','Ifapatienthasbeenprescribeddrugs','Retrospective',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RECENT',1,NULL,NULL,NULL,NULL,'TREATMENT',0,6,1,'2011-03-0815:33:20',0,NULL,NULL,NULL,1,'2011-03-0815:33:20','a1dafc96-4988-11e0-8fc9-544249e49b14');
/*!40000 ALTER TABLE `task` ENABLE KEYS*/;
UNLOCK TABLES;
