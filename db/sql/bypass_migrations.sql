-- Delete the values that we are going to insert
DELETE FROM schema_migrations WHERE version IN
('20181114114615',
'20181114123526',
'20181119083341',
'20181119175307',
'20181120072351',
'20181127093727',
'20181210093633',
'20190516134103',
'20210127082844',
'20210224142005');

-- Do some insertions
INSERT INTO schema_migrations (version) VALUES
('20181114114615'),
('20181114123526'),
('20181119083341'),
('20181119175307'),
('20181120072351'),
('20181127093727'),
('20181210093633'),
('20190516134103'),
('20210127082844'),
('20210224142005');

-- disable foreign key checks
SET FOREIGN_KEY_CHECKS = 0;

-- because we have skipped these we need to create them manually here
CREATE TABLE IF NOT EXISTS  `report_def` (
  `report_def_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` mediumtext NOT NULL,
  `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
  `creator` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`report_def_id`),
  KEY `User who created report_def` (`creator`),
  CONSTRAINT `User who created report_def` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS  `moh_regimen_doses` (
  `dose_id` int(11) NOT NULL AUTO_INCREMENT,
  `am` float DEFAULT NULL,
  `pm` float DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`dose_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;


CREATE TABLE IF NOT EXISTS  `moh_regimen_ingredient` (
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
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS  `reporting_report_design` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(38) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `report_definition_id` int(11) NOT NULL DEFAULT '0',
  `renderer_type` varchar(255) NOT NULL,
  `properties` text,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(255) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `report_definition_id for reporting_report_design` (`report_definition_id`),
  KEY `creator for reporting_report_design` (`creator`),
  KEY `changed_by for reporting_report_design` (`changed_by`),
  KEY `retired_by for reporting_report_design` (`retired_by`),
  CONSTRAINT `changed_by for reporting_report_design` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `creator for reporting_report_design` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `report_definition_id for reporting_report_design` FOREIGN KEY (`report_definition_id`) REFERENCES `report_def` (`report_def_id`),
  CONSTRAINT `retired_by for reporting_report_design` FOREIGN KEY (`retired_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS  `reporting_report_design_resource` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(38) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `report_design_id` int(11) NOT NULL DEFAULT '0',
  `content_type` varchar(50) DEFAULT NULL,
  `extension` varchar(20) DEFAULT NULL,
  `contents` longblob,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '1900-01-01 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(255) DEFAULT NULL,
  `indicator_name` varchar(255) DEFAULT NULL,
  `indicator_short_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `report_design_id for reporting_report_design_resource` (`report_design_id`),
  KEY `creator for reporting_report_design_resource` (`creator`),
  KEY `changed_by for reporting_report_design_resource` (`changed_by`),
  KEY `retired_by for reporting_report_design_resource` (`retired_by`),
  CONSTRAINT `changed_by for reporting_report_design_resource` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `creator for reporting_report_design_resource` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
  CONSTRAINT `report_design_id for reporting_report_design_resource` FOREIGN KEY (`report_design_id`) REFERENCES `reporting_report_design` (`id`),
  CONSTRAINT `retired_by for reporting_report_design_resource` FOREIGN KEY (`retired_by`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS  `pharmacy_obs` (
  `pharmacy_module_id` int(11) NOT NULL AUTO_INCREMENT,
  `pharmacy_encounter_type` int(11) NOT NULL DEFAULT '0',
  `quantity` double DEFAULT NULL,
  `creator` int(11) NOT NULL,
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `voided` tinyint(1) NOT NULL DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  `date_voided` datetime DEFAULT NULL,
  `void_reason` varchar(225) DEFAULT NULL,
  `batch_item_id` int(11) DEFAULT NULL,
  `dispensation_obs_id` int(11) DEFAULT NULL,
  `transaction_reason` text,
  `transaction_date` date DEFAULT NULL,
  `stock_verification_id` bigint(20) DEFAULT NULL,
  `obs_group_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`pharmacy_module_id`),
  KEY `fk_rails_c51641b979` (`dispensation_obs_id`),
  KEY `index_pharmacy_obs_on_stock_verification_id` (`stock_verification_id`),
  KEY `fk_rails_353402f537` (`obs_group_id`),
  CONSTRAINT `fk_rails_353402f537` FOREIGN KEY (`obs_group_id`) REFERENCES `pharmacy_obs` (`pharmacy_module_id`),
  CONSTRAINT `fk_rails_7f4aa3b94b` FOREIGN KEY (`stock_verification_id`) REFERENCES `pharmacy_stock_verifications` (`id`),
  CONSTRAINT `fk_rails_c51641b979` FOREIGN KEY (`dispensation_obs_id`) REFERENCES `obs` (`obs_id`)
) ENGINE=InnoDB AUTO_INCREMENT=326602 DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `pharmacy_encounter_type` (
  `pharmacy_encounter_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `description` text NOT NULL,
  `format` varchar(50) DEFAULT NULL,
  `foreign_key` int(11) DEFAULT NULL,
  `searchable` tinyint(1) DEFAULT NULL,
  `creator` int(11) NOT NULL DEFAULT '0',
  `date_created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `changed_by` int(11) DEFAULT NULL,
  `date_changed` datetime DEFAULT NULL,
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `retired_by` int(11) DEFAULT NULL,
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(225) DEFAULT NULL,
  PRIMARY KEY (`pharmacy_encounter_type_id`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;

-- enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;