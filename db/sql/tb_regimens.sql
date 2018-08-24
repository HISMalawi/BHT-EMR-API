-- MySQL dump 10.13  Distrib 5.1.54, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: openmrs17
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
-- Table structure for table `tb_regimen`
--

DROP TABLE IF EXISTS `tb_regimen`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_regimen` (
  `regimen_id` int(11) NOT NULL AUTO_INCREMENT,
  `concept_id` int(11) NOT NULL DEFAULT '0',
  `regimen_index` int(2) NOT NULL DEFAULT '0' COMMENT 'To keep the index for the regimen',
  `min_weight` int(3) NOT NULL DEFAULT '0',
  `max_weight` int(3) NOT NULL DEFAULT '200',
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `retired` smallint(6) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `program_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`regimen_id`),
  KEY `tb_map_concept` (`concept_id`),
  CONSTRAINT `tb_map_concept` FOREIGN KEY (`concept_id`) REFERENCES `concept` (`concept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=68 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tb_regimen`
--

LOCK TABLES `tb_regimen` WRITE;
/*!40000 ALTER TABLE `tb_regimen` DISABLE KEYS */;
INSERT INTO `tb_regimen` VALUES (1,1131,-1,30,38,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(2,1131,-1,38,55,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(3,1131,-1,55,75,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(4,1131,-1,75,200,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(5,1194,-1,0,8,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(6,1194,-1,8,10,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(7,1194,-1,10,15,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(8,1194,-1,15,20,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(9,1194,-1,20,25,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(10,1194,-1,25,30,1,'2011-08-22 15:50:44',0,NULL,NULL,2),(11,1194,-1,30,38,1,'2011-08-22 15:51:05',0,NULL,NULL,2),(12,1194,-1,38,55,1,'2011-08-22 15:51:05',0,NULL,NULL,2),(13,1194,-1,55,75,1,'2011-08-22 15:51:05',0,NULL,NULL,2),(14,1194,-1,75,200,1,'2011-08-22 15:51:05',0,NULL,NULL,2),(15,768,-1,0,8,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(16,768,-1,8,10,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(17,768,-1,10,15,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(18,768,-1,15,20,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(19,768,-1,20,25,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(20,768,-1,25,30,1,'2011-08-22 15:57:21',0,NULL,NULL,2),(21,745,-1,0,8,1,'2011-08-22 16:02:53',0,NULL,NULL,2),(22,745,-1,8,10,1,'2011-08-22 16:02:53',0,NULL,NULL,2),(23,745,-1,10,15,1,'2011-08-22 16:02:53',0,NULL,NULL,2),(24,745,-1,15,20,1,'2011-08-22 16:02:53',0,NULL,NULL,2),(25,745,-1,20,25,1,'2011-08-22 16:02:53',0,NULL,NULL,2),(26,745,-1,25,30,1,'2011-08-22 16:02:53',0,NULL,NULL,2);
/*!40000 ALTER TABLE `tb_regimen` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tb_regimen_drug_order`
--

DROP TABLE IF EXISTS `tb_regimen_drug_order`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tb_regimen_drug_order` (
  `regimen_drug_order_id` int(11) NOT NULL AUTO_INCREMENT,
  `regimen_id` int(11) NOT NULL DEFAULT '0',
  `drug_inventory_id` int(11) DEFAULT '0',
  `dose` double DEFAULT NULL,
  `equivalent_daily_dose` double DEFAULT NULL,
  `units` varchar(255) DEFAULT NULL,
  `frequency` varchar(255) DEFAULT NULL,
  `prn` tinyint(1) NOT NULL DEFAULT '0',
  `complex` tinyint(1) NOT NULL DEFAULT '0',
  `quantity` int(11) DEFAULT NULL,
  `instructions` text,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `voided` smallint(6) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  `uuid` char(38) NOT NULL,
  PRIMARY KEY (`regimen_drug_order_id`),
  UNIQUE KEY `tb_regimen_drug_order_uuid_index` (`uuid`),
  KEY `tb_regimen_drug_order_creator` (`creator`),
  KEY `user_who_voided_tb_regimen_drug_order` (`voided_by`),
  KEY `tb_map_regimen` (`regimen_id`),
  KEY `tb_map_drug_inventory` (`drug_inventory_id`),
  CONSTRAINT `tb_map_drug_inventory` FOREIGN KEY (`drug_inventory_id`) REFERENCES `drug` (`drug_id`),
  CONSTRAINT `tb_map_regimen` FOREIGN KEY (`regimen_id`) REFERENCES `tb_regimen` (`regimen_id`),
  CONSTRAINT `tb_regimen_drug_order_creator` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `tb_user_who_voided_regimen_drug_order` FOREIGN KEY (`voided_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=86 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tb_regimen_drug_order`
--

LOCK TABLES `tb_regimen_drug_order` WRITE;
/*!40000 ALTER TABLE `tb_regimen_drug_order` DISABLE KEYS */;
/*!40000 ALTER TABLE `tb_regimen_drug_order` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-08-22 16:47:54
