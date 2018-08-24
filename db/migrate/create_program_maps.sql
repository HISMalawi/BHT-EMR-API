DROP TABLE IF EXISTS `program_location_restriction`;
CREATE TABLE `program_location_restriction` (
  `program_location_restriction_id` int(11) NOT NULL auto_increment,
  `program_id` int(11),
  `location_id` int(11),
  PRIMARY KEY  (`program_location_restriction_id`),
  KEY `program_mapping` (`program_id`,`location_id`),
  CONSTRAINT `referenced_program` FOREIGN KEY (`program_id`) REFERENCES `program` (`program_id`),
  CONSTRAINT `referenced_location` FOREIGN KEY (`location_id`) REFERENCES `location` (`location_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `program_encounter_type_map`;
CREATE TABLE `program_encounter_type_map` (
  `program_encounter_type_map_id` int(11) NOT NULL auto_increment,
  `program_id` int(11),
  `encounter_type_id` int(11),
  PRIMARY KEY  (`program_encounter_type_map_id`),
  KEY `program_mapping` (`program_id`,`encounter_type_id`),
  CONSTRAINT `referenced_program_encounter_type_map` FOREIGN KEY (`program_id`) REFERENCES `program` (`program_id`),
  CONSTRAINT `referenced_encounter_type` FOREIGN KEY (`encounter_type_id`) REFERENCES `encounter_type` (`encounter_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `program_patient_identifier_type_map`;
CREATE TABLE `program_patient_identifier_type_map` (
  `program_patient_identifier_type_map_id` int(11) NOT NULL auto_increment,
  `program_id` int(11),
  `patient_identifier_type_id` int(11),
  PRIMARY KEY  (`program_patient_identifier_type_map_id`),
  KEY `program_mapping` (`program_id`,`patient_identifier_type_id`),
  CONSTRAINT `referenced_program_patient_identifier_type_map` FOREIGN KEY (`program_id`) REFERENCES `program` (`program_id`),
  CONSTRAINT `referenced_patient_identifier_type` FOREIGN KEY (`patient_identifier_type_id`) REFERENCES `patient_identifier_type` (`patient_identifier_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `program_relationship_type_map`;
CREATE TABLE `program_relationship_type_map` (
  `program_relationship_type_map_id` int(11) NOT NULL auto_increment,
  `program_id` int(11),
  `relationship_type_id` int(11),
  PRIMARY KEY  (`program_relationship_type_map_id`),
  KEY `program_mapping` (`program_id`,`relationship_type_id`),
  CONSTRAINT `referenced_program_relationship_type_map` FOREIGN KEY (`program_id`) REFERENCES `program` (`program_id`),
  CONSTRAINT `referenced_relationship_type` FOREIGN KEY (`relationship_type_id`) REFERENCES `relationship_type` (`relationship_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `program_orders_map`;
CREATE TABLE `program_orders_map` (
  `program_orders_map_id` int(11) NOT NULL auto_increment,
  `program_id` int(11),
  `concept_id` int(11),
  PRIMARY KEY  (`program_orders_map_id`),
  KEY `program_mapping` (`program_id`,`concept_id`),
  CONSTRAINT `referenced_program_orders_type_map` FOREIGN KEY (`program_id`) REFERENCES `program` (`program_id`),
  CONSTRAINT `referenced_concept_id` FOREIGN KEY (`concept_id`) REFERENCES `concept` (`concept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

