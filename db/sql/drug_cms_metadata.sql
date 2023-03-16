-- MySQL dump 10.13  Distrib 8.0.31, for Linux (x86_64)
--
-- Host: localhost    Database: openmrs
-- ------------------------------------------------------
-- Server version	5.6.51

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `drug_cms`
--

DROP TABLE IF EXISTS `drug_cms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `drug_cms` (
  `drug_inventory_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `code` varchar(255) DEFAULT NULL,
  `short_name` varchar(225) DEFAULT NULL,
  `tabs` varchar(225) DEFAULT NULL,
  `pack_size` int(11) DEFAULT NULL,
  `weight` int(11) DEFAULT NULL,
  `strength` varchar(255) DEFAULT NULL,
  `voided` tinyint(4) DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(225) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `drug_cms`
--

LOCK TABLES `drug_cms` WRITE;
/*!40000 ALTER TABLE `drug_cms` DISABLE KEYS */;
INSERT INTO `drug_cms` VALUES (105,'Acyclovir 200mg',NULL,'Acyclovir 200mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',1),(1044,'Abacavir and Lamivudine 120mg pack of 60 tablets',' GF5118 ','ABC 120 /3TC 300mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',2),(969,'Abacavir sulfate 600mg / Lamivudine 300mg, tin of 30 tablets',' GF1103 ','ABC 600 / 3TC 300mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',3),(932,'Atazanavir / Ritonavir 300 / 100mg, tin of 30 tablets',' GF0570 ','ATV 300 / r 100mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',4),(39,'Zidovudine / lamivudine 300 / 150mg, tin of 60 tablets',' GF0011 ','AZT 300 /3TC 150mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',5),(731,'Zidovudine / lamivudine /Nevirapine 300 / 150 / 200mg, tin of 60 tablets',' GF0058 ','AZT 300 / 3TC 150 / NVP 200mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',6),(732,'Zidovudine / lamivudine /Nevirapine 60 / 30 / 50mg, tin of 60 tablets',' GF0070 ','AZT 60 / 3TC 30 / NVP 50mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',7),(736,'Zidovudine / lamivudine 60 / 30mg, tin of 60 tablets',' GF0071 ','AZT 60 / 3TC 30mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',8),(963,'Cotrimoxazole 120mg, blister pack of 1000 dispersible tablets',' GF0583 ','CPT 120mg',NULL,1000,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',9),(297,'Cotrimoxazole 480mg, tin of 1000 tablets',' GF0405 ','CPT 480mg',NULL,1000,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',10),(576,'Cotrimoxazole 960mg, blister pack of 1000 tablets',' GF0584 ','CPT 960mg',NULL,1000,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',11),(976,'Darunavir 600mg pack of 60 tablets',' GF1104 ','DRV 600mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',12),(980,'Dolutegravir 10mg pack of 90 tablets',' GF5282 ','DTG 10mg',NULL,90,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',13),(982,'Dolutegravir 50mg pack of 30 tablets',' GF5022 ','DTG 50mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',14),(30,'Efavirenz 200mg, tin of 90 tablets',' GF0074 ','EFV 200mg',NULL,90,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',15),(11,'Efavirenz 600mg, tin of 30 tablets',' GF0063 ','EFV 600mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',16),(978,'Etravirine 100mg, tin of 120 tablets',NULL,'ETV 100mg',NULL,120,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',17),(24,'Isoniazid (H) 100mg, blist packs of 100 tablets',NULL,'Isoniazid 100mg',NULL,100,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',18),(991,'Isoniazid (H) 300mg, blist packs of 1000 tablets','GF0013 ','Isoniazid 300mg',NULL,1000,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',19),(74,'Lopinavir / Ritonavir 100 / 25mg, tin of 60 tablets',' GF0076 ','LPV 100 / r 25mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',20),(73,'Lopinavir / Ritonavir 200 / 50mg, tin of 120 tablets',' GF0065 ','LPV 200 / r 50mg',NULL,120,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',21),(1045,'Lopinavir/Ritonavir(LPV/r ), 40/10mg granules, pack of 120 sachets',' GF5116 ','LPV 40 / r 10mg granules',NULL,120,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',22),(979,'Lopinavir/Ritonavir(LPV/r ), 40/10mg granules, pack of 120 pellets',NULL,'LPV 40 / r 10mg pellets',NULL,120,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',23),(22,'Nevirapine 200mg, tin of 60 tablets',' GF0010 ','NVP 200mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',24),(968,'Nevirapine 50mg, tin of 60 tablets',NULL,'NVP 50mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',25),(1039,'Pyridoxine (25mg)',NULL,'Pyridoxine 25mg',NULL,1000,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',26),(977,'Ritonavir 100mg pack of 60 tablets',NULL,'r 100mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',27),(1043,'Raltegravir 25mg pack of 60 tablets',' GF5165 ','RAL 25mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',28),(954,'Raltegravir 400mg pack of 60 tablets',' GF5104 ','RAL 400mg',NULL,60,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',29),(1056,'Rifapentine 150mg pack of 24 tablets',' GF5166 ','Rifapentine 150mg',NULL,24,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',30),(734,'Lamivudine / Tenofovir disoproxil fumarate 300 / 300mg, tin of 30 tablets',' GF0072 ','TDF 300 / 3TC 300mg ',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',31),(735,'Tenofovir disoproxil fumarate / Lamivudine / Efavirenz 300 / 300 / 600mg, tin of 30 tablets',NULL,'TDF 300 / 3TC 300 / EFV 600mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',32),(983,'Tenofovir Disoproxil Fumarate/Lamivudine/Dolutegravir (TDF/3TC /DTG), 300/300/50mg, pack of 90 tablets',' GF0078-A','TDF 300 / 3TC 300 / DTG 50mg',NULL,90,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',33),(983,'Tenofovir Disoproxil Fumarate/Lamivudine/Dolutegravir (TDF/3TC /DTG), 300/300/50mg, pack of 30 tablets',' GF0078 ','TDF 300 / 3TC 300 / DTG 50mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'2022-11-30 13:09:58','2022-11-30 13:09:58',34),(1217,'Tenofovir disoproxil fumarate / Lamivudine / Efavirenz 300 / 300 / 400mg; tin of 30 tablets ',' GF5228 ','TDF 300 / 3TC 300 / EFV 400mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',35),(977,'Ritonavir 100mg pack of 30 tablets',' GF5163 ','r 100mg',NULL,30,NULL,NULL,0,NULL,NULL,NULL,'2022-11-30 13:20:45','2022-11-30 13:20:45',36),(1214,'Darunavir 150mg pack of 240 tablets',' GF5109 ','DRV 150mg',NULL,240,NULL,NULL,0,NULL,NULL,NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',37),(1216,'Isoniazid / Rifapentine 300 / 300mg; blister pack of 36 tablets ',' GF5313 ','INH 300 / RFP 300',NULL,36,NULL,NULL,0,NULL,NULL,NULL,'2022-11-30 13:45:17','2022-11-30 13:45:17',38);
/*!40000 ALTER TABLE `drug_cms` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2022-12-21  7:37:11
