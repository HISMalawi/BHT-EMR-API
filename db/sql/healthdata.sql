-- MySQL dump 10.13  Distrib 5.5.49, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: healthdata2
-- ------------------------------------------------------
-- Server version	5.5.49-0ubuntu0.14.04.1

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
-- Table structure for table `Clinician`
--

DROP TABLE IF EXISTS `Clinician`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Clinician` (
  `Clinician_F_Name` varchar(20) NOT NULL DEFAULT '',
  `Clinician_L_Name` varchar(20) NOT NULL DEFAULT '',
  `Clinician_ID` varchar(6) NOT NULL DEFAULT '',
  `Date_Last_Used` varchar(11) DEFAULT NULL,
  `Cadre` char(2) DEFAULT NULL,
  `DateReg` varchar(11) DEFAULT NULL,
  `remarks` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`Clinician_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Clinician`
--

LOCK TABLES `Clinician` WRITE;
/*!40000 ALTER TABLE `Clinician` DISABLE KEYS */;
INSERT INTO `Clinician` VALUES ('Admin','Lab User','190012',NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `Clinician` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `LabTestTable`
--

DROP TABLE IF EXISTS `LabTestTable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `LabTestTable` (
  `AccessionNum` int(11) NOT NULL AUTO_INCREMENT,
  `TestOrdered` varchar(30) NOT NULL DEFAULT '',
  `Pat_ID` varchar(13) NOT NULL DEFAULT '',
  `OrderDate` varchar(11) NOT NULL DEFAULT '',
  `OrderTime` varchar(8) NOT NULL DEFAULT '',
  `OrderedBy` varchar(6) NOT NULL DEFAULT '',
  `Location` varchar(25) DEFAULT NULL,
  `RcvdAtLabDate` varchar(11) DEFAULT NULL,
  `RcvdAtLabTime` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`AccessionNum`,`TestOrdered`)
) ENGINE=MyISAM AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `LabTestTable`
--

LOCK TABLES `LabTestTable` WRITE;
/*!40000 ALTER TABLE `LabTestTable` DISABLE KEYS */;
INSERT INTO `LabTestTable` VALUES (1,'HIV_viral_load','L4L1PW','2015-04-29','07:41:21','201','St Gabriels Hospital',NULL,NULL),(2,'HIV_viral_load','JDAF1F','2015-10-21','08:28:16','201','St Gabriels Hospital',NULL,NULL),(3,'HIV_viral_load','LV99V0','2014-10-13','08:58:52','212','St Gabriels Hospital',NULL,NULL),(4,'HIV_viral_load','MG7RVY','2016-08-17','09:18:14','201','St Gabriels Hospital',NULL,NULL),(5,'HIV_viral_load','JNX2FE','2016-09-24','09:21:45','211','St Gabriels Hospital',NULL,NULL),(6,'HIV_viral_load','LMVGVX','2014-08-27','08:23:22','153','St Gabriels Hospital',NULL,NULL),(7,'HIV_viral_load','LT9YR5','2016-10-28','08:39:40','153','St Gabriels Hospital',NULL,NULL),(8,'HIV_viral_load','M07XT2','2016-11-16','07:35:01','211','St Gabriels Hospital',NULL,NULL),(9,'HIV_viral_load','HUCXW1','2016-11-16','08:59:58','211','St Gabriels Hospital',NULL,NULL),(10,'HIV_viral_load','KHGG9F','2016-10-14','08:21:17','153','St Gabriels Hospital',NULL,NULL),(11,'HIV_viral_load','K497PW','2016-07-12','08:36:43','209','St Gabriels Hospital',NULL,NULL);
/*!40000 ALTER TABLE `LabTestTable` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Lab_Parameter`
--

DROP TABLE IF EXISTS `Lab_Parameter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Lab_Parameter` (
  `Sample_ID` int(11) DEFAULT NULL,
  `TESTTYPE` int(10) unsigned DEFAULT NULL,
  `TESTVALUE` double DEFAULT NULL,
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `Range` enum('<','=','>') NOT NULL DEFAULT '=',
  PRIMARY KEY (`ID`),
  KEY `FK_sample_id` (`Sample_ID`)
) ENGINE=MyISAM AUTO_INCREMENT=264266 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Lab_Parameter`
--

LOCK TABLES `Lab_Parameter` WRITE;
/*!40000 ALTER TABLE `Lab_Parameter` DISABLE KEYS */;
/*!40000 ALTER TABLE `Lab_Parameter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `Lab_Sample`
--

DROP TABLE IF EXISTS `Lab_Sample`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Lab_Sample` (
  `Sample_ID` int(20) unsigned NOT NULL AUTO_INCREMENT,
  `AccessionNum` int(10) unsigned DEFAULT NULL,
  `PATIENTID` varchar(15) DEFAULT NULL,
  `TESTDATE` varchar(11) DEFAULT NULL,
  `USERID` varchar(255) DEFAULT NULL,
  `DATE` varchar(255) DEFAULT NULL,
  `TIME` varchar(255) DEFAULT NULL,
  `SOURCE` int(11) DEFAULT '0',
  `UpdateBy` varchar(255) DEFAULT NULL,
  `UpdateTimeStamp` varchar(255) DEFAULT NULL,
  `DeleteYN` smallint(6) DEFAULT NULL,
  `Attribute` enum('pass','fail','lost','voided') DEFAULT NULL,
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Sample_ID`),
  UNIQUE KEY `IndexAccessNum` (`AccessionNum`)
) ENGINE=MyISAM AUTO_INCREMENT=63273 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `Lab_Sample`
--

LOCK TABLES `Lab_Sample` WRITE;
/*!40000 ALTER TABLE `Lab_Sample` DISABLE KEYS */;
/*!40000 ALTER TABLE `Lab_Sample` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `codes_TestType`
--

DROP TABLE IF EXISTS `codes_TestType`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `codes_TestType` (
  `TestType` smallint(6) NOT NULL,
  `TestName` varchar(50) DEFAULT NULL,
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Panel_ID` int(11) NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=71 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `codes_TestType`
--

LOCK TABLES `codes_TestType` WRITE;
/*!40000 ALTER TABLE `codes_TestType` DISABLE KEYS */;
INSERT INTO `codes_TestType` VALUES (9,'CD3_count',1,4),(3,'CD4_count',2,4),(4,'CD8_count',3,4),(5,'CD4_CD8_ratio',4,4),(6,'HIV_RNA_PCR',5,12),(70,'CD3_percent',6,4),(71,'CD4_percent',7,4),(72,'CD8_percent',8,0),(12,'CD8Tube',9,0),(10,'ReagentLotID',10,0),(11,'CD4Tube',11,0),(12,'CD8Tube',12,0),(14,'ControlRunReagentLotID',13,0),(15,'ControlRunControlLotID',14,0),(9,'TotalCD3Average',15,0),(7,'CD4_CD3_ratio',16,4),(8,'CD8_CD3_ratio',17,4),(16,'Alanine_Aminotransferase',18,15),(17,'Albumin',19,15),(18,'Alkaline_Phosphatase',20,15),(19,'Amylase',21,22),(20,'Aspartate_Transaminase',22,15),(21,'Basophil_count',23,25),(22,'Basophil_percent',24,25),(23,'Bilirubin_direct',25,15),(24,'Bilirubin_total',26,15),(25,'Urea_Nitrogen_blood',27,17),(26,'Calcium',28,3),(27,'Carbon_Dioxide',29,30),(28,'Cell_count_pleural',30,29),(29,'Chloride',31,17),(30,'Cholesterol',32,21),(31,'Creatinine',33,6),(32,'Cryptococcal_Antigen',34,7),(33,'Eosinophil_count',35,25),(34,'Eosinophil_percent',36,25),(35,'Glucose_blood',37,26),(36,'Glucose_CSF',38,27),(37,'Glutamyl_Transferase',39,15),(38,'Hematocrit',40,10),(39,'Hemoglobin',41,10),(40,'HepBsAg',42,23),(41,'HIV_DNA_PCR',43,12),(42,'India_Ink',44,13),(43,'Lactate',45,14),(44,'Lymphocyte_count',46,10),(45,'Lymphocyte_percent',47,10),(46,'Malaria_Parasite_count',48,16),(47,'MCH',49,10),(48,'MCHC',50,10),(49,'MCV',51,10),(50,'Monocyte_count',52,25),(51,'MPV',53,0),(52,'Neutrophil_count',54,25),(53,'Neutrophil_percent',55,25),(54,'Phosphorus',56,3),(55,'Platelet_count',57,10),(56,'Potassium',58,17),(57,'RBC',59,10),(58,'RDW',60,0),(59,'Sodium',61,17),(60,'RPR_Syphilis',62,20),(61,'Protein_total',63,15),(62,'Toxoplasma_IgG',64,28),(63,'Triglycerides',65,21),(64,'WBC_count',66,10),(65,'WBC_percent',67,10),(66,'Monocyte_percent',68,25),(73,'Lipase',70,0);
/*!40000 ALTER TABLE `codes_TestType` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `map_lab_panel`
--

DROP TABLE IF EXISTS `map_lab_panel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `map_lab_panel` (
  `rec_id` int(4) DEFAULT NULL,
  `name` text,
  `short_name` varchar(60) DEFAULT NULL,
  `count_of_accession_num` int(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `map_lab_panel`
--

LOCK TABLES `map_lab_panel` WRITE;
/*!40000 ALTER TABLE `map_lab_panel` DISABLE KEYS */;
INSERT INTO `map_lab_panel` VALUES (26,'blood glucose','BLOOD_gluc',0),(27,'cerebrospinal fluid glucose','CSF_gluc',0),(28,'toxoplasmosis serology','TOXO',0),(29,'pleural fluid cell count','PLEU_cells',0),(30,'other','OTHER',0),(1,'acid fast bacilli smear microscopy','AFB_smear',645),(2,'blood culture and      sensitivity','Blood_C_S',37),(3,'calcium and phosphate in serum','Ca_PO4',3),(4,'CD4 immunology','CD4',26551),(5,'cholesterine','Cholest',6),(6,'creatinine','Creat',64),(7,'cryptococcal antigen','Crypto_AG',142),(8,'cerebrospinal fluid culture and sensitivity','CSF_C_S',39),(9,'erythrocyte sedimentation rate','ESR',29),(10,'full blood count','FBC',4729),(11,'cerebrospinal fluid full analysis','CSF_full',567),(12,'HIV viral load','HIV_viral_load',50),(13,'cerebrospinal fluid microscopy india ink stain','CSF_indiaink',340),(14,'lactate','Lactate',219),(15,'liver function tests','LFT',702),(16,'malaria parasites','MP',2367),(17,'urea and electolytes','U&E',809),(18,'urine culture and sensitivity','Urine_C_S',97),(19,'urine microscopy','Urine_micro',114),(20,'syphilis serology','VDRL',195),(21,'lipid profile','LIP',0),(22,'amylase','AMYL',0),(23,'hepatitis B serology','HEPB',0),(24,'acid fast bacilli culture','AFB_culture',0),(25,'white blood cell differential count','WBC_diff',0),(26,'blood glucose','BLOOD_gluc',0),(27,'cerebrospinal fluid glucose','CSF_gluc',0),(28,'toxoplasmosis serology','TOXO',0),(29,'pleural fluid cell count','PLEU_cells',0),(30,'other','OTHER',0),(1,'acid fast bacilli smear microscopy','AFB_smear',645),(2,'blood culture and sensitivity','Blood_C_S',37),(3,'calcium and phosphate in serum','Ca_PO4',3),(4,'CD4 immunology','CD4',26551),(5,'cholesterine','Cholest',6),(6,'creatinine','Creat',64),(7,'cryptococcal antigen','Crypto_AG',142),(8,'cerebrospinal fluid culture and sensitivity','CSF_C_S',39),(9,'erythrocyte sedimentation rate','ESR',29),(10,'full blood count','FBC',4729),(11,'cerebrospinal fluid full analysis','CSF_full',567),(12,'HIV viral load','HIV_viral_load',50),(13,'cerebrospinal fluid microscopy india ink stain','CSF_indiaink',340),(14,'lactate','Lactate',219),(15,'liver function tests','LFT',702),(16,'malaria parasites','MP',2367),(17,'urea and electolytes','U&E',809),(18,'urine culture and sensitivity','Urine_C_S',97),(19,'urine microscopy','Urine_micro',114),(20,'syphilis serology','VDRL',195),(21,'lipid profile','LIP',0),(22,'amylase','AMYL',0),(23,'hepatitis B serology','HEPB',0),(24,'acid fast bacilli culture','AFB_culture',0),(25,'white blood cell differential count','WBC_diff',0),(26,'blood glucose','BLOOD_gluc',0),(27,'cerebrospinal fluid glucose','CSF_gluc',0),(28,'toxoplasmosis serology','TOXO',0),(29,'pleural fluid cell count','PLEU_cells',0),(30,'other','OTHER',0),(1,'acid fast bacilli smear microscopy','AFB_smear',645),(2,'blood culture and sensitivity','Blood_C_S',37),(3,'calcium and phosphate in serum','Ca_PO4',3),(4,'CD4 immunology','CD4',26551),(5,'cholesterine','Cholest',6),(6,'creatinine','Creat',64),(7,'cryptococcal antigen','Crypto_AG',142),(8,'cerebrospinal fluid culture and sensitivity','CSF_C_S',39),(9,'erythrocyte sedimentation rate','ESR',29),(10,'full blood count','FBC',4729),(11,'cerebrospinal fluid full analysis','CSF_full',567),(12,'HIV viral load','HIV_viral_load',50),(13,'cerebrospinal fluid microscopy india ink stain','CSF_indiaink',340),(14,'lactate','Lactate',219),(15,'liver function tests','LFT',702),(16,'malaria parasites','MP',2367),(17,'urea and electolytes','U&E',809),(18,'urine culture and sensitivity','Urine_C_S',97),(19,'urine microscopy','Urine_micro',114),(20,'syphilis serology','VDRL',195),(21,'lipid profile','LIP',0),(22,'amylase','AMYL',0),(23,'hepatitis B serology','HEPB',0),(24,'acid fast bacilli culture','AFB_culture',0),(25,'white blood cell differential count','WBC_diff',0);
/*!40000 ALTER TABLE `map_lab_panel` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-04-18 16:02:27
