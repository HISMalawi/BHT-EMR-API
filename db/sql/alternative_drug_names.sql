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
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-01-23 13:42:50
