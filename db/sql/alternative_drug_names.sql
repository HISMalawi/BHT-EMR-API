-- MySQL dump 10.13  Distrib 8.0.12, for osx10.13 (x86_64)
--
-- Host: localhost    Database: mlambe_api
-- ------------------------------------------------------
-- Server version	8.0.12

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8mb4 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `alternative_drug_names`
--

DROP TABLE IF EXISTS `alternative_drug_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE `alternative_drug_names` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  `drug_inventory_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `alternative_drug_names`
--

LOCK TABLES `alternative_drug_names` WRITE;
/*!40000 ALTER TABLE `alternative_drug_names` DISABLE KEYS */;
INSERT INTO `alternative_drug_names` VALUES (1,'Efavirenz 600mg','EFV 600',11,'2018-12-19 09:13:48','2018-12-19 09:13:48'),(2,'Nevirapine 10mg/ml','NVP 10',21,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(3,'Nevirapine 200mg','NVP 200',22,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(4,'Isoniazid 100mg','Isoniazid 100',24,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(5,'Efavirenz 200mg','EFV 200',30,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(6,'Zidovudine / lamivudine 300 / 150mg','AZT 300 / 3TC 150',39,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(7,'Lopinavir / Ritonavir 200 / 50mg','LPV/r 200/50',73,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(8,'Lopinavir / Ritonavir 100 / 25mg','LPV/ r  100/25',74,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(9,'Pyridoxine 50mg tab','Pyridoxine 50',76,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(10,'Cotrimoxazole 480mg','CPT 480',297,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(11,'Cotrimoxazole 960mg','CPT 960',576,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(12,'Lamivudine / Stavudine / Nevirapine 150 / 30 / 200mg','d4T 150 /3TC 30 / NVP 200',613,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(13,'Zidovudine / lamivudine /Nevirapine 300 / 150 / 200mg','AZT 300 / 3TC 150 / NVP 200',731,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(14,'Zidovudine / lamivudine /Nevirapine 30 / 60 / 50mg','AZT 30 / 3TC 60 / NVP 50',732,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(15,'Abacavir / Lamivudine 60 / 30mg','ABC 60 / 3TC 30',733,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(16,'Lamivudine / Tenofovir disoproxil fumarate 300 / 300mg','TDF 300 / 3TC 300',734,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(17,'Tenofovir disoproxil fumarate / Lamivudine / Efavirenz 300 / 300 / 600mg','TDF 300 / 3TC 300 / EFV 600',735,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(18,'Zidovudine / lamivudine 60 / 30mg','AZT 60 / 3TC 30',736,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(19,'Stavudine / lamivudine 30 / 150mg','d4T 30 / 3TC 150',738,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(20,'Isoniazid 300mg','Isoniazid 300',931,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(21,'Atazanavir / Ritonavir 300 / 100mg','ATV/r 300/100',932,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(22,'Cotrimoxazole 120mg','CTX 120',963,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(23,'Nevirapine 50mg','NVP 50',968,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(24,'Abacavir sulfate 600mg / Lamivudine 300mg','ABC 600 / 3TC 300',969,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(25,'Nevirapine 10mg/ml','NVP 10',971,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(26,'Dolugravir (10mg tablet)','DTG 10',980,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(27,'Dolugravir (25mg tablet)','DTG 25',981,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(28,'Dolugravir (50mg tablet)','DTG 50',982,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(29,'Darunavir 600mg','DRV 600',976,'2018-12-19 09:13:49','2018-12-19 09:13:49'),(30,'Ritonavir 100mg','r 100',977,'2018-12-19 09:13:49','2018-12-19 09:13:49');
/*!40000 ALTER TABLE `alternative_drug_names` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2018-12-19 12:18:28
