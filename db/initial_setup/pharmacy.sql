-- MySQL dump 10.13  Distrib 5.1.41, for debian-linux-gnu (i486)
--
-- Host: localhost    Database: bart
-- ------------------------------------------------------
-- Server version	5.1.41-3ubuntu12.8

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
-- Table structure for table `pharmacy_encounter_type`
--

DROP TABLE IF EXISTS `pharmacy_encounter_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pharmacy_encounter_type` (
  `pharmacy_encounter_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `description` text NOT NULL,
  `format` varchar(50) DEFAULT NULL,
  `foreign_key` int(11) DEFAULT NULL,
  `searchable` tinyint(1) DEFAULT NULL,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(225) DEFAULT NULL,
  PRIMARY KEY (`pharmacy_encounter_type_id`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pharmacy_encounter_type`
--

LOCK TABLES `pharmacy_encounter_type` WRITE;
/*!40000 ALTER TABLE `pharmacy_encounter_type` DISABLE KEYS */;
INSERT INTO `pharmacy_encounter_type` VALUES (5,'Edited stock','Edited stock',NULL,NULL,NULL,1,'2010-08-18 03:12:00',NULL,NULL,0,NULL,NULL,NULL),(3,'Tins removed','Number of  tins removed stock',NULL,NULL,NULL,1,'2010-03-26 03:12:00',NULL,NULL,0,NULL,NULL,NULL),(1,'Tins in previous stock','Number of tins in previous stock',NULL,NULL,NULL,1,'2010-03-26 03:12:00',NULL,NULL,0,NULL,NULL,NULL),(2,'New deliveries','Number of new deliveries',NULL,NULL,NULL,1,'2010-03-26 03:12:00',NULL,NULL,0,NULL,NULL,NULL),(4,'Tins currently in stock','Number of tins currently in  stock (physically counted)',NULL,NULL,NULL,1,'2010-03-26 03:12:00',NULL,NULL,0,NULL,NULL,NULL);
/*!40000 ALTER TABLE `pharmacy_encounter_type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pharmacy_obs`
--

DROP TABLE IF EXISTS `pharmacy_obs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pharmacy_obs` (
  `pharmacy_module_id` int(11) NOT NULL AUTO_INCREMENT,
  `pharmacy_encounter_type` int(11) NOT NULL DEFAULT '0',
  `drug_id` int(11) NOT NULL DEFAULT '0',
  `value_numeric` double DEFAULT NULL,
  `expiring_units` double DEFAULT NULL,
  `pack_size` int(11) DEFAULT NULL,
  `value_coded` int(11) DEFAULT NULL,
  `value_text` varchar(15) DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `encounter_date` date NOT NULL DEFAULT '0000-00-00',
  `creator` int(11) NOT NULL,
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(225) DEFAULT NULL,
  PRIMARY KEY (`pharmacy_module_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pharmacy_obs`
--

LOCK TABLES `pharmacy_obs` WRITE;
/*!40000 ALTER TABLE `pharmacy_obs` DISABLE KEYS */;
/*!40000 ALTER TABLE `pharmacy_obs` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2010-12-22 16:30:10
