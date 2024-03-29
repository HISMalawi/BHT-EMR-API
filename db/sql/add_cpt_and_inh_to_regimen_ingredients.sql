-- MySQL dump 10.13  Distrib 5.7.24, for Linux (x86_64)
--
-- Host: localhost    Database: bht_core_dev
-- ------------------------------------------------------
-- Server version	5.7.24-0ubuntu0.18.04.1

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
) ENGINE=InnoDB AUTO_INCREMENT=103 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `moh_regimen_ingredient`
--

LOCK TABLES `moh_regimen_ingredient` WRITE;
/*!40000 ALTER TABLE `moh_regimen_ingredient` DISABLE KEYS */;
INSERT INTO `moh_regimen_ingredient` VALUES (1,1,733,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(2,1,968,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(3,1,733,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(4,1,968,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(5,1,733,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(6,1,968,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(7,1,733,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(8,1,968,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(9,1,733,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(10,1,968,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(11,1,969,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(12,1,22,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(13,2,732,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(14,2,732,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(15,2,732,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(16,2,732,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(17,2,732,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(18,2,731,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(19,3,736,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(20,3,30,6,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(22,3,736,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(23,3,736,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(24,3,736,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(25,3,736,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(26,3,30,7,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(27,3,30,8,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(28,3,11,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(29,3,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(30,4,735,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(31,5,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(32,5,22,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(33,6,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(34,6,932,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(35,7,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(36,7,932,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(37,8,733,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(38,8,733,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(39,8,733,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(40,8,733,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(41,8,733,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(42,8,969,6,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(43,8,979,3,3,3.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(44,8,979,3,4,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(45,8,74,10,6,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(46,8,74,3,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(47,8,74,5,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(48,8,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(49,9,734,6,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(50,9,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(51,10,736,1,3,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(52,10,736,2,6,9.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(53,10,736,3,10,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(54,10,736,4,14,19.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(55,10,736,5,20,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(56,10,979,3,3,3.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(57,10,979,3,4,5.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(58,10,74,10,6,13.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(59,10,74,3,14,24.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(60,10,74,5,25,34.9,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(61,10,39,1,25,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(62,10,73,3,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(63,11,976,1,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(64,11,977,1,35,300,'2016-09-19 16:00:00','2016-09-19 16:00:00',1,0,NULL,0,120,'MF'),(67,12,983,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(68,13,982,6,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(69,14,982,6,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(70,13,984,1,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(71,14,969,13,30,300,'2018-10-19 10:36:10','2018-10-19 10:36:10',NULL,0,NULL,0,120,'M'),(77,12,983,13,30,300,'2018-11-02 14:22:11','2018-11-02 14:22:11',1,0,NULL,45,120,'F'),(78,13,982,6,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(79,14,982,6,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(80,13,984,1,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(81,14,969,13,30,300,'2018-11-02 14:22:12','2018-11-02 14:22:12',1,0,NULL,45,120,'F'),(82,NULL,963,6,3,5.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(83,NULL,963,1,6,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(84,NULL,963,3,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(85,NULL,297,9,6,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(86,NULL,297,6,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(87,NULL,297,8,25,200,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(88,NULL,576,9,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(89,NULL,576,6,25,200,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(90,NULL,24,9,3,5.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(91,NULL,24,6,6,9.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(92,NULL,24,7,10,13.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(93,NULL,24,8,14,19.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(94,NULL,24,11,20,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(95,NULL,931,9,14,24.9,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(96,NULL,931,6,25,300,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(97,NULL,83,13,3,300,NULL,NULL,NULL,0,NULL,NULL,NULL,'MF'),(102,11,982,6,30,300,'2019-01-14 13:54:51',NULL,1,0,NULL,NULL,NULL,'MF');
/*!40000 ALTER TABLE `moh_regimen_ingredient` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-01-14 13:56:02
