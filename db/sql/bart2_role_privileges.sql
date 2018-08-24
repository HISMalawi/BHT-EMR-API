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
-- Table structure for table `role_privilege`
--


--
-- Dumping data for table `role_privilege`
--

LOCK TABLES `role_privilege` WRITE;   
/*!40000 ALTER TABLE `role_privilege` DISABLE KEYS */;
INSERT INTO `role_privilege` VALUES ('System Developer','Manage appointments'),('System Developer','Manage ART adherence'),('System Developer','Manage ART visits'),('System Developer','Manage drug dispensations'),('System Developer','Manage HIV first visits'),('System Developer','Manage HIV reception visits'),('System Developer','Manage HIV staging visits'),('System Developer','Manage Patient Programs'),('System Developer','Manage pre ART visits'),('System Developer','Manage prescriptions'),('System Developer','Manage Relationships'),('System Developer','Manage TB Reception Visits'),('System Developer','Manage Vitals'),('System Developer','Manage HIV Status Visits'),('System Developer','Manage TB Clinic Visits'), ('System Developer','Manage TB Registration Visits'), ('System Developer','Manage Lab Orders'), ('System Developer','Manage Sputum Submissions'), ('System Developer','Manage Lab Results'), ('System Developer','Manage TB Treatment Visits'), ('System Developer','Manage TB adherence'), ('System Developer','Manage TB initial visits'), ('System Developer','Give Lab Results'), ('System Developer','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Registration Clerk','Manage appointments'),('Registration Clerk','Manage ART adherence'),('Registration Clerk','Manage ART visits'),('Registration Clerk','Manage drug dispensations'),('Registration Clerk','Manage HIV first visits'),('Registration Clerk','Manage HIV reception visits'),('Registration Clerk','Manage HIV staging visits'),('Registration Clerk','Manage Patient Programs'),('Registration Clerk','Manage pre ART visits'),('Registration Clerk','Manage prescriptions'),('Registration Clerk','Manage Relationships'),('Registration Clerk','Manage TB Reception Visits'),('Registration Clerk','Manage Vitals'),('Registration Clerk','Manage HIV Status Visits'),('Registration Clerk','Manage TB Clinic Visits'), ('Registration Clerk','Manage TB Registration Visits'), ('Registration Clerk','Manage Lab Orders'), ('Registration Clerk','Manage Sputum Submissions'), ('Registration Clerk','Manage Lab Results'), ('Registration Clerk','Manage TB Treatment Visits'), ('Registration Clerk','Manage TB adherence'), ('Registration Clerk','Manage TB initial visits'), ('Registration Clerk','Give Lab Results'), ('Registration Clerk','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Vitals Clerk','Manage appointments'),('Vitals Clerk','Manage ART adherence'),('Vitals Clerk','Manage ART visits'),('Vitals Clerk','Manage drug dispensations'),('Vitals Clerk','Manage HIV first visits'),('Vitals Clerk','Manage HIV reception visits'),('Vitals Clerk','Manage HIV staging visits'),('Vitals Clerk','Manage Patient Programs'),('Vitals Clerk','Manage pre ART visits'),('Vitals Clerk','Manage prescriptions'),('Vitals Clerk','Manage Relationships'),('Vitals Clerk','Manage TB Reception Visits'),('Vitals Clerk','Manage Vitals'),('Vitals Clerk','Manage HIV Status Visits'),('Vitals Clerk','Manage TB Clinic Visits'), ('Vitals Clerk','Manage TB Registration Visits'), ('Vitals Clerk','Manage Lab Orders'), ('Vitals Clerk','Manage Sputum Submissions'), ('Vitals Clerk','Manage Lab Results'), ('Vitals Clerk','Manage TB Treatment Visits'), ('Vitals Clerk','Manage TB adherence'), ('Vitals Clerk','Manage TB initial visits'), ('Vitals Clerk','Give Lab Results'), ('Vitals Clerk','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Nurse','Manage appointments'),('Nurse','Manage ART adherence'),('Nurse','Manage ART visits'),('Nurse','Manage drug dispensations'),('Nurse','Manage HIV first visits'),('Nurse','Manage HIV reception visits'),('Nurse','Manage HIV staging visits'),('Nurse','Manage Patient Programs'),('Nurse','Manage pre ART visits'),('Nurse','Manage prescriptions'),('Nurse','Manage Relationships'),('Nurse','Manage TB Reception Visits'),('Nurse','Manage Vitals'),('Nurse','Manage HIV Status Visits'),('Nurse','Manage TB Clinic Visits'), ('Nurse','Manage TB Registration Visits'), ('Nurse','Manage Lab Orders'), ('Nurse','Manage Sputum Submissions'), ('Nurse','Manage Lab Results'), ('Nurse','Manage TB Treatment Visits'), ('Nurse','Manage TB adherence'), ('Nurse','Manage TB initial visits'), ('Nurse','Give Lab Results'), ('Nurse','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Clinician','Manage appointments'),('Clinician','Manage ART adherence'),('Clinician','Manage ART visits'),('Clinician','Manage drug dispensations'),('Clinician','Manage HIV first visits'),('Clinician','Manage HIV reception visits'),('Clinician','Manage HIV staging visits'),('Clinician','Manage Patient Programs'),('Clinician','Manage pre ART visits'),('Clinician','Manage prescriptions'),('Clinician','Manage Relationships'),('Clinician','Manage TB Reception Visits'),('Clinician','Manage Vitals'),('Clinician','Manage HIV Status Visits'),('Clinician','Manage TB Clinic Visits'), ('Clinician','Manage TB Registration Visits'), ('Clinician','Manage Lab Orders'), ('Clinician','Manage Sputum Submissions'), ('Clinician','Manage Lab Results'), ('Clinician','Manage TB Treatment Visits'), ('Clinician','Manage TB adherence'), ('Clinician','Manage TB initial visits'), ('Clinician','Give Lab Results'), ('Clinician','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Pharmacist','Manage appointments'),('Pharmacist','Manage ART adherence'),('Pharmacist','Manage ART visits'),('Pharmacist','Manage drug dispensations'),('Pharmacist','Manage HIV first visits'),('Pharmacist','Manage HIV reception visits'),('Pharmacist','Manage HIV staging visits'),('Pharmacist','Manage Patient Programs'),('Pharmacist','Manage pre ART visits'),('Pharmacist','Manage prescriptions'),('Pharmacist','Manage Relationships'),('Pharmacist','Manage TB Reception Visits'),('Pharmacist','Manage Vitals'),('Pharmacist','Manage HIV Status Visits'),('Pharmacist','Manage TB Clinic Visits'), ('Pharmacist','Manage TB Registration Visits'), ('Pharmacist','Manage Lab Orders'), ('Pharmacist','Manage Sputum Submissions'), ('Pharmacist','Manage Lab Results'), ('Pharmacist','Manage TB Treatment Visits'), ('Pharmacist','Manage TB adherence'), ('Pharmacist','Manage TB initial visits'), ('Pharmacist','Give Lab Results'), ('Pharmacist','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Provider','Manage appointments'),('Provider','Manage ART adherence'),('Provider','Manage ART visits'),('Provider','Manage drug dispensations'),('Provider','Manage HIV first visits'),('Provider','Manage HIV reception visits'),('Provider','Manage HIV staging visits'),('Provider','Manage Patient Programs'),('Provider','Manage pre ART visits'),('Provider','Manage prescriptions'),('Provider','Manage Relationships'),('Provider','Manage TB Reception Visits'),('Provider','Manage Vitals'), ('Provider','Manage Lab Orders'), ('Provider','Manage Sputum Submissions'), ('Provider','Manage Lab Results'), ('Provider','Manage TB Treatment Visits'), ('Provider','Manage TB adherence'), ('Provider','Manage TB initial visits'), ('Provider','Give Lab Results'), ('Provider','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Superuser','Manage appointments'),('Superuser','Manage ART adherence'),('Superuser','Manage ART visits'),('Superuser','Manage drug dispensations'),('Superuser','Manage HIV first visits'),('Superuser','Manage HIV reception visits'),('Superuser','Manage HIV staging visits'),('Superuser','Manage Patient Programs'),('Superuser','Manage pre ART visits'),('Superuser','Manage prescriptions'),('Superuser','Manage Relationships'),('Superuser','Manage TB Reception Visits'),('Superuser','Manage Vitals'),('Superuser','Manage HIV Status Visits'),('Superuser','Manage TB Clinic Visits'), ('Superuser','Manage TB Registration Visits'), ('Superuser','Manage Lab Orders'), ('Superuser','Manage Sputum Submissions'), ('Superuser','Manage Lab Results'), ('Superuser','Manage TB Treatment Visits'), ('Superuser','Manage TB adherence'), ('Superuser','Manage TB initial visits'), ('Superuser','Give Lab Results'), ('Superuser','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('General Registration Clerk','Manage appointments'),('General Registration Clerk','Manage ART adherence'),('General Registration Clerk','Manage ART visits'),('General Registration Clerk','Manage drug dispensations'),('General Registration Clerk','Manage HIV first visits'),('General Registration Clerk','Manage HIV reception visits'),('General Registration Clerk','Manage HIV staging visits'),('General Registration Clerk','Manage Patient Programs'),('General Registration Clerk','Manage pre ART visits'),('General Registration Clerk','Manage prescriptions'),('General Registration Clerk','Manage Relationships'),('General Registration Clerk','Manage TB Reception Visits'),('General Registration Clerk','Manage Vitals'),('General Registration Clerk','Manage HIV Status Visits'),('General Registration Clerk','Manage TB Clinic Visits'), ('General Registration Clerk','Manage TB Registration Visits'), ('General Registration Clerk','Manage Lab Orders'), ('General Registration Clerk','Manage Sputum Submissions'), ('General Registration Clerk','Manage Lab Results'), ('General Registration Clerk','Manage TB Treatment Visits'), ('General Registration Clerk','Manage TB adherence'), ('General Registration Clerk','Manage TB initial visits'), ('General Registration Clerk','Give Lab Results'), ('General Registration Clerk','Manage Source of Referral');

INSERT INTO `role_privilege` VALUES ('Data Assistant','Manage appointments'),('Data Assistant','Manage ART adherence'),('Data Assistant','Manage ART visits'),('Data Assistant','Manage drug dispensations'),('Data Assistant','Manage HIV first visits'),('Data Assistant','Manage HIV reception visits'),('Data Assistant','Manage HIV staging visits'),('Data Assistant','Manage Patient Programs'),('Data Assistant','Manage pre ART visits'),('Data Assistant','Manage prescriptions'),('Data Assistant','Manage Relationships'),('Data Assistant','Manage TB Reception Visits'),('Data Assistant','Manage Vitals'),('Data Assistant','Manage HIV Status Visits'),('Data Assistant','Manage TB Clinic Visits'), ('Data Assistant','Manage TB Registration Visits'), ('Data Assistant','Manage Lab Orders'), ('Data Assistant','Manage Sputum Submissions'), ('Data Assistant','Manage Lab Results'), ('Data Assistant','Manage TB Treatment Visits'), ('Data Assistant','Manage TB adherence'), ('Data Assistant','Manage TB initial visits'), ('Data Assistant','Give Lab Results'), ('Data Assistant','Manage Source of Referral');

/*!40000 ALTER TABLE `role_privilege` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-08-11 10:36:37
