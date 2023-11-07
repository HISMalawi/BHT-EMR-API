SET FOREIGN_KEY_CHECKS = 0;
CREATE TABLE IF NOT EXISTS `order_extension` (
  `order_extension_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `value` varchar(50) NOT NULL DEFAULT '',
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`order_extension_id`),
  KEY `user_who_created_ext` (`creator`),
  KEY `user_who_retired_ext` (`voided_by`),
  KEY `retired_status` (`voided`),
  CONSTRAINT `user_who_created_extension` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `user_who_voided_extension` FOREIGN KEY (`voided_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `drug_substance` (
  `drug_substance_id` int(11) NOT NULL AUTO_INCREMENT,
  `concept_id` int(11) NOT NULL DEFAULT '0',
  `name` varchar(50) DEFAULT NULL,
  `dose_strength` double DEFAULT NULL,
  `maximum_daily_dose` double DEFAULT NULL,
  `minimum_daily_dose` double DEFAULT NULL,
  `route` int(11) DEFAULT NULL,
  `units` varchar(50) DEFAULT NULL,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` datetime DEFAULT NULL,
  PRIMARY KEY (`drug_substance_id`),
  KEY `drug_ingredient_creator` (`creator`),
  KEY `primary_drug_ingredient_concept` (`concept_id`),
  KEY `route_concept` (`route`),
  KEY `user_who_retired_drug` (`retired_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `location_drugs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `drug_id` int(11) DEFAULT NULL,
  `drug_name` varchar(255) DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `malaria_occurences_by_age_and_period` (
  `person_id` int(11) DEFAULT NULL,
  `age` float DEFAULT NULL,
  `period` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `mulinda_patient_demographics` (
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `person_id` int(11) NOT NULL DEFAULT '0',
  `gender` varchar(50) CHARACTER SET utf8 DEFAULT '',
  `birthdate` date DEFAULT NULL,
  `birthdate_estimated` smallint(6) NOT NULL DEFAULT '0',
  `marital_status` mediumtext CHARACTER SET utf8,
  `current_district` varchar(50) CHARACTER SET utf8 DEFAULT NULL,
  `location` varchar(50) CHARACTER SET utf8 DEFAULT NULL,
  `date_of_last_visit` date DEFAULT NULL,
  `total_number_of_visits` bigint(21) DEFAULT NULL,
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `mulinda_patient_diagnosis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `visit_date` date NOT NULL,
  `time_stamp` datetime DEFAULT NULL,
  `primary_diagnosis` varchar(245) DEFAULT NULL,
  `detailed_primary_diagnosis` varchar(245) DEFAULT NULL,
  `specific_primary_diagnosis` varchar(245) DEFAULT NULL,
  `secondary_diagnosis` varchar(245) DEFAULT NULL,
  `detailed_secondary_diagnosis` varchar(245) DEFAULT NULL,
  `specific_secondary_diagnosis` varchar(245) DEFAULT NULL,
  `additional_diagnosis` varchar(245) DEFAULT NULL,
  `detailed_additional_diagnosis` varchar(245) DEFAULT NULL,
  `specific_additional_diagnosis` varchar(245) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=598720 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `mulinda_patient_referred_from` (
  `patient_id` int(11) NOT NULL,
  `visit_date` date DEFAULT NULL,
  `time_stamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `loc` longtext CHARACTER SET utf8
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `mulinda_patient_vitals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `visit_date` date NOT NULL,
  `time_stamp` datetime DEFAULT NULL,
  `height` varchar(45) DEFAULT NULL,
  `weight` varchar(45) DEFAULT NULL,
  `temp` varchar(45) DEFAULT NULL,
  `pulse` varchar(45) DEFAULT NULL,
  `diastolic_bp` varchar(45) DEFAULT NULL,
  `systolic_bp` varchar(45) DEFAULT NULL,
  `respiratory_rate` varchar(45) DEFAULT NULL,
  `blood_oxygen_saturation` varchar(45) DEFAULT NULL,
  `triage_category` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=598732 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `mulinda_smokers_drinkers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL,
  `visit_date` date NOT NULL,
  `smoker` varchar(45) DEFAULT NULL,
  `drinker` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=183270 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `patient_identifiers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `person_attribute_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `person_attributes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `program_encounters` (
  `program_encounter_id` int(11) NOT NULL AUTO_INCREMENT,
  `encounter_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `voided` tinyint(4) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`program_encounter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `regimen_criteria` (
  `regimen_criteria_id` int(11) NOT NULL AUTO_INCREMENT,
  `concept_id` int(11) NOT NULL DEFAULT '0',
  `min_weight` int(3) NOT NULL DEFAULT '0',
  `max_weight` int(3) NOT NULL DEFAULT '200',
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `retired` smallint(6) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  PRIMARY KEY (`regimen_criteria_id`),
  KEY `map_concept` (`concept_id`),
  CONSTRAINT `map_concept` FOREIGN KEY (`concept_id`) REFERENCES `concept` (`concept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=62 DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `user_activation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `system_id` varchar(45) NOT NULL,
  `status` varchar(45) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=412 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `users_barcode_login` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `date_created` datetime NOT NULL,
  `user_uuid` varchar(36) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `visit` (
  `visit_id` int(11) NOT NULL AUTO_INCREMENT,
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `end_date` datetime DEFAULT NULL,
  `ended_by` int(11) NOT NULL DEFAULT '0',
  `creator` int(11) NOT NULL,
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`visit_id`),
  KEY `visit_patient_id` (`patient_id`)
) ENGINE=InnoDB AUTO_INCREMENT=113940 DEFAULT CHARSET=latin1;
CREATE TABLE IF NOT EXISTS `visit_encounters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `visit_id` int(11) NOT NULL,
  `encounter_id` int(11) NOT NULL,
  `creator` int(11) NOT NULL,
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `visit_id_enc_id_index` (`visit_id`,`encounter_id`)
) ENGINE=InnoDB AUTO_INCREMENT=373180 DEFAULT CHARSET=latin1;
-- ALTER TABLE formentry_xsn ADD COLUMN uuid char(38) NOT NULL ;
-- ALTER TABLE htmlformentry_html_form ADD COLUMN uuid char(38) NOT NULL ;
-- ALTER TABLE htmlformentry_html_form ADD COLUMN description varchar(1000) NULL ;
-- ALTER TABLE htmlformentry_html_form ADD COLUMN retired_by int(11) NULL ;
-- ALTER TABLE htmlformentry_html_form ADD COLUMN date_retired datetime NULL ;
-- ALTER TABLE htmlformentry_html_form ADD COLUMN retire_reason varchar(255) NULL ;
-- ALTER TABLE obs ADD COLUMN value_location int(11) NULL ;
-- ALTER TABLE weight_for_heights ADD COLUMN supinecm double NOT NULL ;
SET FOREIGN_KEY_CHECKS = 1;
