
CREATE TABLE `dset` (
  `set_id` int(11)  NOT NULL AUTO_INCREMENT,
  `name` text DEFAULT NULL,
  `description` text DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) NOT NULL,
  `status` varchar(25) NOT NULL,
   PRIMARY KEY (`set_id`)
);

CREATE TABLE `drug_set` (
  `drug_set_id` int(11) NOT NULL AUTO_INCREMENT,
  `drug_inventory_id` int(11)  REFERENCES drug (drug_id),
  `set_id` int(11)  REFERENCES dset (set_id),
  `frequency` varchar(255) NOT NULL,
  `duration` varchar(255) NOT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_updated` datetime DEFAULT NULL,
  `creator` int(11) DEFAULT NULL,
  `voided` tinyint(1) NOT NULL  DEFAULT '0',
  `voided_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`drug_set_id`)
);
