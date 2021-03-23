-- MySQL dump 10.13  Distrib 5.7.27, for Linux (x86_64)
--
-- Host: localhost    Database: bht_core_dev
-- ------------------------------------------------------
-- Server version	5.7.27-0ubuntu0.18.04.1

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
-- Table structure for table `moh_regimens`
--

DROP TABLE IF EXISTS `moh_regimens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimens` (
  `regimen_id` int(11) NOT NULL AUTO_INCREMENT,
  `regimen_index` int(11) NOT NULL,
  `description` text,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) NOT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`regimen_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimens`
--

LOCK TABLES `moh_regimens` WRITE;
/*!40000 ALTER TABLE `moh_regimens` DISABLE KEYS */;
INSERT INTO `moh_regimens` VALUES (1,0,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(2,2,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(3,4,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(4,5,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(5,6,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(6,7,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(7,8,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(8,9,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(9,10,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(10,11,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(11,12,NULL,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(12,13,NULL,NULL,NULL,1,0,NULL),(13,14,NULL,NULL,NULL,1,0,NULL),(14,15,NULL,NULL,NULL,1,0,NULL);
/*!40000 ALTER TABLE `moh_regimens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_regimen_ingredient`
--

DROP TABLE IF EXISTS `moh_regimen_ingredient`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimen_ingredient` (
  `ingredient_id` int(11) NOT NULL AUTO_INCREMENT,
  `regimen_id` int(11) DEFAULT NULL,
  `drug_inventory_id` int(11) DEFAULT NULL,
  `dose_id` int(11) DEFAULT NULL,
  `min_weight` float DEFAULT NULL,
  `max_weight` float DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `min_age` int(11) DEFAULT NULL,
  `max_age` int(11) DEFAULT NULL,
  `gender` varchar(255) DEFAULT 'MF',
  PRIMARY KEY (`ingredient_id`)
) ENGINE=InnoDB AUTO_INCREMENT=107 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_ingredient`
--

LOCK TABLES `moh_regimen_ingredient` WRITE;
/*!40000 ALTER TABLE `moh_regimen_ingredient` DISABLE KEYS */;
INSERT INTO `moh_regimen_ingredient` VALUES (1,1,733,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(2,1,968,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(3,1,733,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(4,1,968,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(5,1,733,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(6,1,968,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(7,1,733,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(8,1,968,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(9,1,733,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(10,1,968,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(11,1,969,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(12,1,22,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(13,2,732,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(14,2,732,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(15,2,732,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(16,2,732,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(17,2,732,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(18,2,731,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(19,3,736,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(20,3,30,6,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(22,3,736,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(23,3,736,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(24,3,736,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(25,3,736,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(26,3,30,7,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(27,3,30,8,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(28,3,11,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(29,3,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(30,4,735,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(31,5,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(32,5,22,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(33,6,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(34,6,932,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(35,7,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(36,7,932,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(37,8,733,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(38,8,733,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(39,8,733,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(40,8,733,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(41,8,733,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(42,8,969,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(43,8,979,3,3,3.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(44,8,979,3,4,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(45,8,74,10,6,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(46,8,74,3,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(47,8,74,5,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(48,8,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(49,9,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(50,9,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(51,10,736,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(52,10,736,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(53,10,736,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(54,10,736,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(55,10,736,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(56,10,979,3,3,3.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(57,10,979,3,4,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(58,10,74,10,6,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(59,10,74,3,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(60,10,74,5,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(61,10,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(62,10,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(63,11,976,1,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(64,11,977,1,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(67,12,983,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(68,13,982,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(69,14,982,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(70,13,984,1,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(71,14,969,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(77,12,983,13,30,300,'2018-11-02 14:22:11','2018-11-02 14:22:11',1,0,NULL,45,120,'F'),(78,13,982,13,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(79,14,982,13,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(80,13,984,1,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(81,14,969,13,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(82,NULL,963,6,3,5.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(83,NULL,963,1,6,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(84,NULL,963,3,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(85,NULL,297,9,6,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(86,NULL,297,6,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(87,NULL,297,8,25,200,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(88,NULL,576,9,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(89,NULL,576,6,25,200,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(90,NULL,24,9,3,5.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(91,NULL,24,6,6,9.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(92,NULL,24,7,10,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(93,NULL,24,8,14,19.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(94,NULL,24,11,20,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(95,NULL,931,9,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(96,NULL,931,6,25,300,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(97,NULL,83,13,3,300,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(102,11,982,13,30,300,'2019-01-14 13:54:51',NULL,1,0,NULL,NULL,NULL,'MF'),(103,8,74,1,3,3.9,'2019-08-09 11:22:34','2019-08-09 11:22:34',1,0,NULL,NULL,NULL,'MF'),(104,8,74,2,4,5.9,'2019-08-09 11:22:55','2019-08-09 11:22:55',1,0,NULL,NULL,NULL,'MF'),(105,10,74,1,3,3.9,'2019-08-09 11:23:29','2019-08-09 11:23:29',1,0,NULL,NULL,NULL,'MF'),(106,10,74,2,4,5.9,'2019-08-09 11:23:43','2019-08-09 11:23:43',1,0,NULL,NULL,NULL,'MF');
/*!40000 ALTER TABLE `moh_regimen_ingredient` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_regimen_lookup`
--

DROP TABLE IF EXISTS `moh_regimen_lookup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimen_lookup` (
  `regimen_lookup_id` int(11) NOT NULL AUTO_INCREMENT,
  `num_of_drug_combination` int(11) DEFAULT NULL,
  `regimen_name` varchar(5) NOT NULL,
  `drug_inventory_id` int(11) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`regimen_lookup_id`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_lookup`
--

LOCK TABLES `moh_regimen_lookup` WRITE;
/*!40000 ALTER TABLE `moh_regimen_lookup` DISABLE KEYS */;
INSERT INTO `moh_regimen_lookup` VALUES (1,2,'0P',733,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(2,2,'0P',968,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(3,2,'0A',969,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(4,2,'0A',22,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(5,1,'2P',732,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(6,1,'2A',731,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(7,2,'4P',736,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(8,2,'4P',30,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(9,2,'4A',39,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(10,2,'4A',11,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(11,1,'5A',735,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(12,2,'6A',734,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(13,2,'6A',22,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(14,2,'7A',734,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(15,2,'7A',932,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(16,2,'8A',39,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(17,2,'8A',932,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(18,2,'9P',733,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(19,2,'9P',74,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(20,2,'9A',969,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(21,2,'9A',73,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(22,2,'10A',734,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(23,2,'10A',73,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(24,2,'11P',736,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(25,2,'11P',74,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(26,2,'11A',39,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(27,2,'11A',73,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(28,4,'12A',976,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(29,4,'12A',977,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(30,4,'12A',954,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(31,4,'12A',978,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(33,2,'9P',979,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(34,2,'11P',979,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(35,1,'13A',983,'2019-08-09 11:00:58','2019-08-09 11:00:58',1,0,NULL),(36,2,'14A',984,'2019-08-09 11:01:41','2019-08-09 11:01:41',1,0,NULL),(37,2,'14A',982,'2019-08-09 11:01:49','2019-08-09 11:01:49',1,0,NULL);
/*!40000 ALTER TABLE `moh_regimen_lookup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_regimen_doses`
--

DROP TABLE IF EXISTS `moh_regimen_doses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimen_doses` (
  `dose_id` int(11) NOT NULL AUTO_INCREMENT,
  `am` float DEFAULT NULL,
  `pm` float DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`dose_id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_doses`
--

LOCK TABLES `moh_regimen_doses` WRITE;
/*!40000 ALTER TABLE `moh_regimen_doses` DISABLE KEYS */;
INSERT INTO `moh_regimen_doses` VALUES (1,1,1,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(2,1.5,1.5,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(3,2,2,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(4,2.5,2.5,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(5,3,3,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(6,0,1,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(7,0,1.5,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(8,0,2,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(9,0,0.5,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(10,2,1,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(11,0,2.5,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(12,0,3,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(13,1,0,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(14,1.5,0,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(15,2,0,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(16,2.5,0,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(17,3,0,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(18,4,4,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL);
/*!40000 ALTER TABLE `moh_regimen_doses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `alternative_drug_names`
--

DROP TABLE IF EXISTS `alternative_drug_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `alternative_drug_names` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  `drug_inventory_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=79 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `alternative_drug_names`
--

LOCK TABLES `alternative_drug_names` WRITE;
/*!40000 ALTER TABLE `alternative_drug_names` DISABLE KEYS */;
INSERT INTO `alternative_drug_names` VALUES (1,'Efavirenz 600mg','EFV 600',11,'2018-12-19 09:13:48','2018-12-19 09:13:48'),(2,'Nevirapine 10mg/ml','NVP 10',21,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(3,'Nevirapine 200mg','NVP 200',22,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(4,'Isoniazid 100mg','Isoniazid 100',24,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(5,'Efavirenz 200mg','EFV 200',30,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(6,'Zidovudine / lamivudine 300 / 150mg','AZT 300 / 3TC 150',39,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(7,'Lopinavir / Ritonavir 200 / 50mg','LPV/r 200/50',73,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(8,'Lopinavir / Ritonavir 100 / 25mg','LPV/ r  100/25',74,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(9,'Pyridoxine 50mg tab','Pyridoxine 50',76,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(10,'Cotrimoxazole 480mg','CPT 480',297,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(11,'Cotrimoxazole 960mg','CPT 960',576,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(12,'Lamivudine / Stavudine / Nevirapine 150 / 30 / 200mg','d4T 150 /3TC 30 / NVP 200',613,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(13,'Zidovudine / lamivudine /Nevirapine 300 / 150 / 200mg','AZT 300 / 3TC 150 / NVP 200',731,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(14,'Zidovudine / lamivudine /Nevirapine 30 / 60 / 50mg','AZT 30 / 3TC 60 / NVP 50',732,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(15,'Abacavir / Lamivudine 60 / 30mg','ABC 60 / 3TC 30',733,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(16,'Lamivudine / Tenofovir disoproxil fumarate 300 / 300mg','TDF 300 / 3TC 300',734,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(17,'Tenofovir disoproxil fumarate / Lamivudine / Efavirenz 300 / 300 / 600mg','TDF 300 / 3TC 300 / EFV 600',735,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(18,'Zidovudine / lamivudine 60 / 30mg','AZT 60 / 3TC 30',736,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(19,'Stavudine / lamivudine 30 / 150mg','d4T 30 / 3TC 150',738,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(20,'Isoniazid 300mg','Isoniazid 300',931,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(21,'Atazanavir / Ritonavir 300 / 100mg','ATV/r 300/100',932,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(22,'Cotrimoxazole 120mg','CTX 120',963,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(23,'Nevirapine 50mg','NVP 50',968,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(24,'Abacavir sulfate 600mg / Lamivudine 300mg','ABC 600 / 3TC 300',969,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(25,'Nevirapine 10mg/ml','NVP 10',971,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(26,'Dolugravir (10mg tablet)','DTG 10',980,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(27,'Dolugravir (25mg tablet)','DTG 25',981,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(28,'Dolugravir (50mg tablet)','DTG 50',982,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(29,'Darunavir 600mg','DRV 600',976,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(30,'Ritonavir 100mg','r 100',977,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(31,'d 4T (Stavudine 30mg tablet)','d 4T (Stavudine 30mg tablet)',5,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(32,'d 4T (Stavudine 40mg tablet)','d 4T (Stavudine 40mg tablet)',6,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(33,'d 4T (Stavudine 20mg tablet)','d 4T (Stavudine 20mg tablet)',31,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(34,'d 4T (Stavudine 15mg tablet)','d 4T (Stavudine 15mg tablet)',32,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(35,'d 4T (Stavudine syrup)','d 4T (Stavudine syrup)',95,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(36,'3TC (Lamivudine syrup 10mg / mL from 100mL bottle)','3TC (Lamivudine syrup 10mg / mL from 100mL bottle)',41,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(37,'3TC (Lamivudine 150mg tablet)','3TC (Lamivudine 150mg tablet)',42,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(38,'Lamivudine (5ml bottle)','Lamivudine (5ml bottle)',177,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(39,'Lamivudine 300','Lamivudine 300',957,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(40,'Zidolam','Zidolam',89,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(41,'AZT 300 / 3TC 300','AZT 300 / 3TC 300',984,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(42,'NVP (Nevirapine syrup 1mL / dose in 25mL bottle)','NVP (Nevirapine syrup 1mL / dose in 25mL bottle)',817,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(43,'EFV (Efavirenz 100mg tablet)','EFV (Efavirenz 100mg tablet)',28,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(44,'EFV (Efavirenz 50mg tablet)','EFV (Efavirenz 50mg tablet)',29,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(45,'NFV(Nelfinavir)','NFV(Nelfinavir)',951,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(46,'Triomune - 30','Triomune - 30',2,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(47,'Triomune - 40','Triomune - 40',3,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(48,'Triomune baby (d 4T / 3TC / NVP 6 / 30 / 50mg tablet)','Triomune baby (d 4T / 3TC / NVP 6 / 30 / 50mg tablet)',72,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(49,'Duovir - N','Duovir - N',104,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(50,'D 4T + 3TC / D 4T + 3TC + NVP','D 4T + 3TC / D 4T + 3TC + NVP',730,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(51,'Triomune junior (d 4T / 3TC / NVP 12 / 60 / 100mg tablet)','Triomune junior (d 4T / 3TC / NVP 12 / 60 / 100mg tablet)',813,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(52,'LPV / r (cold; Lopanavir and Ritonavir 166 mg tab)','LPV / r (cold; Lopanavir and Ritonavir 166 mg tab)',23,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(53,'LPV / r (Lopinavir and Ritonavir syrup)','LPV / r (Lopinavir and Ritonavir syrup)',94,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(54,'LPV / r (Lopinavir and Ritonavir 133 / 33mg tablet)','LPV / r (Lopinavir and Ritonavir 133 / 33mg tablet)',739,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(55,'DDI (Didanosine 125mg tablet)','DDI (Didanosine 125mg tablet)',9,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(56,'DDI (Didanosine 200mg tablet)','DDI (Didanosine 200mg tablet)',10,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(57,'AZT (Zidovudine syrup 10mg / mL from 100ml bottle)','AZT (Zidovudine syrup 10mg / mL from 100ml bottle)',36,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(58,'AZT (Zidovudine 100mg tablet)','AZT (Zidovudine 100mg tablet)',37,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(59,'AZT (Zidovudine 300mg tablet)','AZT (Zidovudine 300mg tablet)',38,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(60,'TDF (Tenofavir 300 mg tablet)','TDF (Tenofavir 300 mg tablet)',14,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(61,'ABC (Abacavir 300mg tablet)','ABC (Abacavir 300mg tablet)',40,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(62,'AZT / 3TC / NVP','AZT / 3TC / NVP',614,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(63,'d 4T / 3TC / EFV (Stavudine Lamvudine Efavirenz)','d 4T / 3TC / EFV (Stavudine Lamvudine Efavirenz)',955,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(64,'LS 30 (Stavudine and Lamivudine 30mg tablet)','LS 30 (Stavudine and Lamivudine 30mg tablet)',70,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(65,'Lamivir baby (Stavudine and Lamivudine 6 / 30mg tabl','Lamivir baby (Stavudine and Lamivudine 6 / 30mg tabl',71,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(66,'Coviro 30 (Lamivudine  +  Stavudine 150 / 30 mg tablet)','Coviro 30 (Lamivudine  +  Stavudine 150 / 30 mg tablet)',90,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(67,'Coviro 40 (Lamivudine  +  Stavudine 150 / 40mg tablet)','Coviro 40 (Lamivudine  +  Stavudine 150 / 40mg tablet)',91,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(68,'d 4T / 3TC (Stavudine Lamivudine 6 / 30mg tablet)','d 4T / 3TC (Stavudine Lamivudine 6 / 30mg tablet)',737,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(69,'DDI / ABC / LPV / r','DDI / ABC / LPV / r',815,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(70,'AZT / 3TC / TDF / LPV / r','AZT / 3TC / TDF / LPV / r',816,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(71,'TDF / d 4T (Tenofavir and Stavudine 300 / 300mg tablet','TDF / d 4T (Tenofavir and Stavudine 300 / 300mg tablet',814,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(72,'TDF / 3TC  +  ALT / r','TDF / 3TC  +  ALT / r',933,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(73,'AZT / 3TC  +  ALT / r','AZT / 3TC  +  ALT / r',934,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(74,'ATV / (Atazanavir)','ATV / (Atazanavir)',952,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(75,'RAL (Raltegravir 400mg)','RAL (Raltegravir 400mg)',954,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(76,'Etravirine 100mg','Etravirine 100mg',978,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(77,'LPV / r pellets','LPV / r pellets',979,'2019-01-23 13:14:06','2019-01-23 13:14:06'),(78,'TDF 300 / 3TC 300 / DTG 50','TDF 300 / 3TC 300 / DTG 50',983,'2019-01-23 13:14:06','2019-01-23 13:14:06');
/*!40000 ALTER TABLE `alternative_drug_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_other_medications`
--

DROP TABLE IF EXISTS `moh_other_medications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_other_medications` (
  `medication_id` int(11) NOT NULL AUTO_INCREMENT,
  `drug_inventory_id` int(11) NOT NULL,
  `dose_id` int(11) NOT NULL,
  `min_weight` float NOT NULL,
  `max_weight` float NOT NULL,
  `category` varchar(1) NOT NULL,
  PRIMARY KEY (`medication_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_other_medications`
--

LOCK TABLES `moh_other_medications` WRITE;
/*!40000 ALTER TABLE `moh_other_medications` DISABLE KEYS */;
INSERT INTO `moh_other_medications` VALUES (1,963,6,3,5.9,'P'),(2,963,1,6,13.9,'P'),(3,963,3,14,24.9,'P'),(4,297,9,6,13.9,'A'),(5,297,6,14,24.9,'A'),(6,297,8,25,300,'A'),(7,576,9,14,24.9,'A'),(8,576,6,25,300,'A'),(9,24,9,3,5.9,'P'),(10,24,6,6,9.9,'P'),(11,24,7,10,13.9,'P'),(12,24,8,14,19.9,'P'),(13,24,11,20,24.9,'P'),(14,931,9,14,24.9,'A'),(15,931,6,25,300,'A');
/*!40000 ALTER TABLE `moh_other_medications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_regimen_ingredient_tb_treatment`
--

DROP TABLE IF EXISTS `moh_regimen_ingredient_tb_treatment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimen_ingredient_tb_treatment` (
  `ingredient_id` int(11) NOT NULL DEFAULT '0',
  `regimen_id` int(11) DEFAULT NULL,
  `drug_inventory_id` int(11) DEFAULT NULL,
  `dose_id` int(11) DEFAULT NULL,
  `min_weight` float DEFAULT NULL,
  `max_weight` float DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_ingredient_tb_treatment`
--

LOCK TABLES `moh_regimen_ingredient_tb_treatment` WRITE;
/*!40000 ALTER TABLE `moh_regimen_ingredient_tb_treatment` DISABLE KEYS */;
INSERT INTO `moh_regimen_ingredient_tb_treatment` VALUES (33,6,73,18,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(34,6,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(35,7,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(36,7,73,18,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL);
/*!40000 ALTER TABLE `moh_regimen_ingredient_tb_treatment` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `moh_regimen_ingredient_starter_packs`
--

DROP TABLE IF EXISTS `moh_regimen_ingredient_starter_packs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moh_regimen_ingredient_starter_packs` (
  `ingredient_id` int(11) NOT NULL AUTO_INCREMENT,
  `regimen_id` int(11) DEFAULT NULL,
  `drug_inventory_id` int(11) DEFAULT NULL,
  `dose_id` int(11) DEFAULT NULL,
  `min_weight` float DEFAULT NULL,
  `max_weight` float DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`ingredient_id`)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_ingredient_starter_packs`
--

LOCK TABLES `moh_regimen_ingredient_starter_packs` WRITE;
/*!40000 ALTER TABLE `moh_regimen_ingredient_starter_packs` DISABLE KEYS */;
INSERT INTO `moh_regimen_ingredient_starter_packs` VALUES (1,1,733,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(2,1,968,6,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(3,1,733,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(4,1,968,7,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(5,1,733,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(6,1,968,8,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(7,1,733,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(8,1,968,11,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(9,1,733,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(10,1,968,12,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(11,1,969,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(12,1,22,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(31,5,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(32,5,22,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(39,2,736,13,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(40,2,736,14,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(41,2,736,15,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(42,2,736,16,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(43,2,736,17,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(44,2,39,13,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(45,2,732,6,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(46,2,732,7,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(47,2,732,8,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(48,2,732,11,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(49,2,732,12,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL),(50,2,731,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL);
/*!40000 ALTER TABLE `moh_regimen_ingredient_starter_packs` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-09-17 15:55:35
