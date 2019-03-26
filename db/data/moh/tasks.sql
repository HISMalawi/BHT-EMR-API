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
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `task`
--

LOCK TABLES `task` WRITE;
/*!40000 ALTER TABLE `task` DISABLE KEYS */;
INSERT INTO `task` VALUES (1,'/encounters/new/registration?patient_id={patient}','REGISTRATION','Always do a Registration here','*',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,1,1,'2011-06-22 15:39:43',0,NULL,NULL,NULL,1,'2011-06-22 15:39:43','15f49016-9cd5-11e0-96f5-544249e49b14'),(2,'/encounters/new/art_initial?show&patient_id={patient}','ART_INITIAL','Not enrolled in HIV programn','HIV Reception',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,1,2,1,'2011-06-22 15:42:50',0,NULL,NULL,NULL,1,'2011-06-22 15:42:50','85b2b6e4-9cd5-11e0-96f5-544249e49b14'),(3,'/encounters/new/hiv_staging?show&patient_id={patient}','HIV STAGING','Ever received ART = YES','HIV Reception',NULL,7754,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,3,1,'2011-06-22 15:45:58',0,NULL,NULL,NULL,1,'2011-06-22 15:45:58','f5725c50-9cd5-11e0-96f5-544249e49b14'),(4,'/encounters/new/hiv_reception?show&patient_id={patient}','HIV RECEPTION','Always do a HIV RECEPTION here','HIV Reception',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,4,1,'2011-06-22 15:51:48',0,NULL,NULL,NULL,1,'2011-06-22 15:51:48','c68ec26a-9cd6-11e0-96f5-544249e49b14'),(5,'/encounters/new/vitals?patient_id={patient}','VITALS','Patient present = YES','Vitals',NULL,1805,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,5,1,'2011-06-22 15:56:21',0,NULL,NULL,NULL,1,'2011-06-22 15:56:50','6914d15a-9cd7-11e0-96f5-544249e49b14'),(6,'/encounters/new/hiv_staging?show&patient_id={patient}','HIV STAGING','Not on ART','HIV Clinician Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,6,1,'2011-06-22 16:20:15',0,NULL,NULL,NULL,1,'2011-06-22 16:20:15','bf8bbb90-9cda-11e0-96f5-544249e49b14'),(7,'/encounters/new/pre_art_visit?show&patient_id={patient}','PART_FOLLOWUP','If patient has no staging condition: Reason for starting = Unknown','HIV Clinician Station',NULL,7563,1067,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,7,1,'2011-06-22 16:24:40',0,NULL,NULL,NULL,1,'2011-06-22 16:24:40','5da2e948-9cdb-11e0-96f5-544249e49b14'),(8,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','On ART','HIV Clinician Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,8,1,'2011-06-22 16:33:36',0,NULL,NULL,NULL,1,'2011-06-22 16:33:36','9d7ad548-9cdc-11e0-96f5-544249e49b14'),(9,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','On ART','HIV Nurse Station',NULL,1805,1065,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,0,9,1,'2011-06-22 16:34:58',0,NULL,NULL,NULL,1,'2011-06-22 16:34:58','cdc5f26e-9cdc-11e0-96f5-544249e49b14'),(10,'/encounters/new/art_adherence?show&patient_id={patient}','ART ADHERENCE','ART ADHERENCE','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,'ART VISIT',0,10,1,'2011-06-22 16:39:17',0,NULL,NULL,NULL,1,'2011-06-22 16:39:33','685fc890-9cdd-11e0-96f5-544249e49b14'),(11,'/regimens/new?patient_id={patient}','TREATMENT','If ART visit today == YES','HIV Clinician Station',NULL,5073,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,11,1,'2011-06-22 16:46:41',0,NULL,NULL,NULL,1,'2011-06-22 16:51:09','70d521a4-9cde-11e0-96f5-544249e49b14'),(12,'/regimens/new?patient_id={patient}','TREATMENT','If ART visit today == YES','HIV Nurse Station',NULL,5073,1065,NULL,NULL,NULL,NULL,'TODAY',1,NULL,NULL,NULL,NULL,NULL,0,12,1,'2011-06-22 16:55:03',0,NULL,NULL,NULL,1,'2011-06-22 16:56:00','9c18b302-9cdf-11e0-96f5-544249e49b14'),(13,'/patients/treatment_dashboard/{patient}','DISPENSING','If a patient has been prescribed drugs','HIV Nurse Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RECENT',1,NULL,NULL,NULL,NULL,'TREATMENT',0,13,1,'2011-06-22 17:00:52',0,NULL,NULL,NULL,1,'2011-06-22 17:00:52','6c53f676-9ce0-11e0-96f5-544249e49b14'),(14,'/patients/treatment_dashboard/{patient}','DISPENSING','If a patient has been prescribed drugs','HIV Pharmacy Station',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RECENT',1,NULL,NULL,NULL,NULL,'TREATMENT',0,14,1,'2011-06-22 17:03:21',0,NULL,NULL,NULL,1,'2011-06-22 17:03:42','c50eae8c-9ce0-11e0-96f5-544249e49b14'),(15,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','Patient not present == YES','HIV Nurse Station',NULL,1805,1066,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,0,15,1,'2011-06-22 17:05:29',0,NULL,NULL,NULL,1,'2011-06-22 17:05:29','1140ff6c-9ce1-11e0-96f5-544249e49b14'),(16,'/encounters/new/art_visit?show&patient_id={patient}','ART VISIT','Patient not present == YES','HIV Clinician Station',NULL,1805,1066,NULL,NULL,NULL,NULL,'TODAY',1,7,NULL,NULL,NULL,NULL,0,16,1,'2011-06-22 18:04:48',0,NULL,NULL,NULL,1,'2011-06-22 18:05:01','5a7db88e-9ce9-11e0-96f5-544249e49b14'),(17,'/patients/treatment_dashboard/{patient}',NULL,'No where to go','Outpatient',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'TODAY',NULL,NULL,NULL,NULL,NULL,NULL,0,17,1,'2011-06-23 09:56:06',0,NULL,NULL,NULL,1,'2011-06-23 09:56:52','400f0a5e-9d6e-11e0-be0c-544249e49b14'),(18,'/patients/show/{patient}',NULL,'No whereto go','*',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,0,18,1,'2011-06-23 10:23:00',0,NULL,NULL,NULL,1,'2011-06-23 10:23:25','019dfbaa-9d72-11e0-be0c-544249e49b14');
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

-- Dump completed on 2011-06-23 10:51:11
