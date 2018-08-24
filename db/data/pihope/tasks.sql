-- MySQL dump 10.13  Distrib 5.1.54, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: bart
-- ------------------------------------------------------
-- Server version	5.1.54-1ubuntu4

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `task`
--

DROP TABLE IF EXISTS `task`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `task` (
  `task_id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(255) DEFAULT NULL,
  `encounter_type` varchar(255) DEFAULT NULL,
  `description` text,
  `location` varchar(255) DEFAULT NULL,
  `gender` varchar(50) DEFAULT NULL,
  `has_obs_concept_id` int(11) DEFAULT NULL,
  `has_obs_value_coded` int(11) DEFAULT NULL,
  `has_obs_value_drug` int(11) DEFAULT NULL,
  `has_obs_value_datetime` datetime DEFAULT NULL,
  `has_obs_value_numeric` double DEFAULT NULL,
  `has_obs_value_text` text,
  `has_obs_scope` text,
  `has_program_id` int(11) DEFAULT NULL,
  `has_program_workflow_state_id` int(11) DEFAULT NULL,
  `has_identifier_type_id` int(11) DEFAULT NULL,
  `has_relationship_type_id` int(11) DEFAULT NULL,
  `has_order_type_id` int(11) DEFAULT NULL,
  `has_encounter_type_today` varchar(255) DEFAULT NULL,
  `skip_if_has` smallint(6) DEFAULT '0',
  `sort_weight` double DEFAULT NULL,
  `creator` int(11) NOT NULL,
  `date_created` datetime NOT NULL,
  `voided` smallint(6) DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `uuid` char(38) DEFAULT NULL,
  PRIMARY KEY (`task_id`),
  KEY `task_creator` (`creator`),
  KEY `user_who_voided_task` (`voided_by`),
  KEY `user_who_changed_task` (`changed_by`),
  CONSTRAINT `task_creator` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `user_who_changed_task` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `user_who_voided_task` FOREIGN KEY (`voided_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=59 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task`
--

LOCK TABLES `task` WRITE;
/*!40000 ALTER TABLE `task` DISABLE KEYS */;
INSERT INTO `task` VALUES (1,'/encounters/new/registration?patient_id={patient}','REGISTRATION','Always do a Registration here','Registration',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,1,1,'2010-02-18 17:25:10',0,NULL,NULL,NULL,1,'2010-02-18 17:25:10','cd5b8184-1ca1-11df-82c4-0026181bb84d'),(2,'/encounters/new/registration?patient_id={patient}','REGISTRATION','Registration for every location','*',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,2,1,'2010-02-18 17:25:10',0,NULL,NULL,NULL,1,'2010-02-18 17:25:10','cd7ab4be-1ca1-11df-82c4-0026181bb84d'),(5,'/patients/show/{patient}',NULL,'Nothing left, go to dashboard','*',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,100,1,'2010-02-18 17:25:11',0,NULL,NULL,NULL,1,'2010-02-18 17:25:11','cdbfda9e-1ca1-11df-82c4-0026181bb84d'),(10,'/encounters/new/vitals?patient_id={patient}','VITALS','Always take the vitals here','Vitals',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,1,1,'2010-02-18 17:25:10',0,NULL,NULL,NULL,1,'2010-02-18 17:25:10','cd934d9e-1ca1-11df-82c4-0026181bb84d'),(21,'/encounters/new/outpatient_diagnosis?patient_id={patient}','OUTPATIENT DIAGNOSIS','Always make a diagnosis here','Outpatient',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,1,1,'2010-02-18 17:25:11',0,NULL,NULL,NULL,1,'2010-02-18 17:25:11','cdaf4f76-1ca1-11df-82c4-0026181bb84d'),(22,'/prescriptions/new?patient_id={patient}','TREATMENT','Always do a treatment here','Outpatient',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,2,1,'2010-02-26 11:10:56',0,NULL,NULL,NULL,1,'2010-02-26 11:10:56','d8cf35a4-22b6-11df-b344-0026181bb84d'),(31,'/encounters/new/art_initial?show&patient_id={patient}','ART_INITIAL','Not enrolled in HIV programn','HIV Reception',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,1,1,1,'2010-02-26 11:25:51',0,NULL,NULL,NULL,1,'2010-02-26 11:25:51','eeba2f84-22b8-11df-b344-0026181bb84d'),(32,'/encounters/new/hiv_reception?show&patient_id={patient}','HIV RECEPTION','Always','HIV Reception',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,3,1,'2010-02-26 11:47:13',0,NULL,NULL,NULL,1,'2010-02-26 11:47:13','ea6de076-22bb-11df-b344-0026181bb84d'),(33,'/encounters/new/vitals?patient_id={patient}','VITALS','PATIENT_PRESENT = YES','HIV Reception',NULL,1805,1065,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,4,1,'2010-02-26 13:45:50',0,NULL,NULL,NULL,1,'2010-02-26 13:45:50','7cc4fc2e-22cc-11df-b344-0026181bb84d'),(34,'/encounters/new/hiv_staging?show&patient_id={patient}','HIV STAGING','EVER RECEIVED ART = YES','HIV Reception',NULL,7754,1065,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,2,1,'2010-02-26 13:45:50',0,NULL,NULL,NULL,1,'2010-02-26 13:45:50','7cc4fc2e-22cc-11df-b344-0026181bb84d'),(35,'/patients/show/{patient}',NULL,'EID patients go straight to Dashboard for now','HIV Reception',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',4,NULL,NULL,NULL,NULL,NULL,0,0,1,'2011-04-30 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(41,'/patients/show/{patient}',NULL,'Stop here if ART ELIGIBILITY = UNKNOWN','HIV Nurse Station',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,98,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(42,'/patients/show/{patient}',NULL,'If TREATMENT today','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,'TREATMENT',0,99,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(43,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','In state On ART','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,0,2,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(44,'/encounters/new/art_adherence?show&patient_id={patient}','ART ADHERENCE','ART ADHERENCE','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ART VISIT',0,3,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,1,'2011-03-08 15:59:44',NULL),(45,'/regimens/new?patient_id={patient}','TREATMENT','If ART Visit today AND REFER TO ART CLINICIAN = NO','HIV Nurse Station',NULL,6969,1066,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ART VISIT',0,4,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(46,'/patients/show/{patient}','TREATMENT','If ART Visit today AND REFER TO ART CLINICIAN = YES','HIV Nurse Station',NULL,6969,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ART VISIT',0,5,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(47,'/encounters/new/appointment?patient_id={patient}','APPOINTMENT','If DISPENSE today','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,'DISPENSE',0,7,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(51,'/encounters/new/hiv_staging?show&patient_id={patient}','HIV STAGING','Not in state On ART','HIV Clinician Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,1,1,1,'2010-02-26 14:00:23',0,NULL,NULL,NULL,1,'2010-02-26 14:00:23','84dd80dc-22ce-11df-b344-0026181bb84d'),(52,'/patients/show/{patient}',NULL,'ART ELIGIBILITY = UNKNOWN','HIV Clinician Station',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,97,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(53,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','NOT ART ELIGIBILITY = UNKNOWN','HIV Clinician Station',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,1,3,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(54,'/regimens/new?patient_id={patient}','TREATMENT','ART VISIT today','HIV Clinician Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ART VISIT',0,5,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(55,'/encounters/new/art_visit?show&patient_id={patient}',NULL,'REFER TO CLINICIAN = YES','HIV Clinician Station',NULL,6969,1065,NULL,NULL,NULL,NULL,'RECENT',NULL,NULL,NULL,NULL,NULL,NULL,0,4,1,'2011-01-13 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(56,'/patients/show/{patient}',NULL,'EID patients go straight to Dashboard for now','HIV Clinician Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',4,NULL,NULL,NULL,NULL,NULL,0,0,1,'2011-04-30 00:00:00',0,NULL,NULL,NULL,NULL,NULL,NULL),(57,'/patients/treatment/{patient}','DISPENSING','If a patient has been prescribed drugs','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RECENT',1,NULL,NULL,NULL,NULL,'TREATMENT',0,6,1,'2011-03-08 15:33:20',0,NULL,NULL,NULL,1,'2011-03-08 15:33:20','a1dafc96-4988-11e0-8fc9-544249e49b14');
/*!40000 ALTER TABLE `task` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-05-23 11:44:48
