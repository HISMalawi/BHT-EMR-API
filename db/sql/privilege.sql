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


LOCK TABLES `privilege` WRITE;
/*!40000 ALTER TABLE `privilege` DISABLE KEYS */;
INSERT INTO `privilege` VALUES ('Manage ART adherence','Able to add, edit, and delete ART adherence data','7233d36c-b93d-11e0-a9ad-544249e49b14'),('Manage ART visits','Able to add, edit, and delete ART visit data','4f8e9940-b934-11e0-a9ad-544249e49b14'),('Manage drug dispensations','Able to add, edit, and delete - Give drugs data','92848740-b92b-11e0-a9ad-544249e49b14'),('Manage HIV first visits','Able to add, edit, and delete HIV first visit data','637115f4-b92b-11e0-a9ad-544249e49b14'),('Manage HIV reception visits','Able to add, edit, and delete HIV Reception data','e7d3c41e-b92a-11e0-a9ad-544249e49b14'),('Manage HIV staging visits','Able to add, edit, and delete HIV staging data','0a26fbe4-b92b-11e0-a9ad-544249e49b14'),('Manage pre ART visits','Able to add, edit, and delete Pre ART visit data','9c131156-b92a-11e0-a9ad-544249e49b14'),('Manage prescriptions','Able to add, edit, and delete prescriptions','e8ee1166-b93d-11e0-a9ad-544249e49b14'),('Manage TB reception visit','Able to add, edit, and delete TB Reception data','0a874fb6-b92c-11e0-a9ad-544249e49b14'),('Manage Vitals','Able to add, edit, and delete Vitals data','712d1d9c-b92a-11e0-a9ad-544249e49b14');
/*!40000 ALTER TABLE `privilege` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-08-11 15:30:31
