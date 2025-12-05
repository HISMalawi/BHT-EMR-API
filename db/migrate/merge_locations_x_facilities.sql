SET FOREIGN_KEY_CHECKS=0;
SET SQL_SAFE_UPDATES=0;

-- ============================================================================
 -- CREATE TABLES IF NOT EXISTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS location_attribute_type (
    location_attribute_type_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255),
    description VARCHAR(255),
    datatype VARCHAR(255),
    min_occurs INT,
    creator INT,
    date_created DATETIME,
    retired INT,
    uuid VARCHAR(255),
    UNIQUE KEY `location_attribute_type_uuid_index` (`uuid`),
    KEY `location_attribute_type_creator` (`creator`),
    CONSTRAINT `location_attribute_type_creator` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`)
);

CREATE TABLE IF NOT EXISTS location_attribute (
    location_attribute_id INT PRIMARY KEY AUTO_INCREMENT,
    location_id INT,
    attribute_type_id INT,
    value_reference VARCHAR(255),
    uuid VARCHAR(255),
    creator INT,
    date_created DATETIME,
    voided INT,
    UNIQUE KEY `location_attribute_uuid_index` (`uuid`),
    KEY `location_attribute_creator` (`creator`),
    CONSTRAINT `location_attribute_creator` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
    KEY `location_attribute_location` (`location_id`),
    CONSTRAINT `location_attribute_location` FOREIGN KEY (`location_id`) REFERENCES `location` (`location_id`),
    KEY `location_attribute_type` (`attribute_type_id`),
    CONSTRAINT `location_attribute_type` FOREIGN KEY (`attribute_type_id`) REFERENCES `location_attribute_type` (`location_attribute_type_id`)
);


-- ============================================================================
-- CREATE LOCATION ATTRIBUTE TYPES
-- ============================================================================

-- Facility Code
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Code',
    'Unique facility code from the facilities table',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Code'
);

-- Facility Common Name
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Common Name',
    'Common name of the facility',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Common Name'
);

-- Facility Ownership
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Ownership',
    'Ownership type of the facility',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Ownership'
);

-- Facility Type
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Type',
    'Type of the facility',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Type'
);

-- Facility Status
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Status',
    'Operational status of the facility',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Status'
);

-- Facility Regulatory Status
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Regulatory Status',
    'Regulatory status of the facility',
    'org.openmrs.customdatatype.datatype.FreeTextDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Regulatory Status'
);

-- Facility Date Opened
INSERT INTO location_attribute_type 
    (name, description, datatype, min_occurs, creator, date_created, retired, uuid)
SELECT 
    'Facility Date Opened',
    'Date when the facility was opened',
    'org.openmrs.customdatatype.datatype.DateDatatype',
    0,
    1,
    NOW(),
    0,
    UUID()
WHERE NOT EXISTS (
    SELECT 1 FROM location_attribute_type WHERE name = 'Facility Date Opened'
);

SELECT 'Location Attribute Types Created' AS status;

-- ============================================================================
-- Update locations table with facility data
-- ============================================================================

UPDATE location l
INNER JOIN temp_facility_x_location_map flm ON l.location_id = flm.location_id
INNER JOIN facilities f ON f.code = flm.facility_code
SET 
    l.name = COALESCE(f.name, l.name),
    l.city_village = COALESCE(f.district, l.city_village),
    l.latitude = COALESCE(f.latitude, l.latitude),
    l.longitude = COALESCE(f.longitude, l.longitude);

SELECT 'Locations Updated' AS status, ROW_COUNT() AS rows_updated;

-- ============================================================================
-- Create location_attribute entries
-- ============================================================================

-- Facility Code
INSERT INTO location_attribute 
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT 
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Code' LIMIT 1),
    f.code,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.code IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Code' LIMIT 1)
);

-- Facility Common Name
INSERT INTO location_attribute 
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT 
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Common Name' LIMIT 1),
    f.common,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.common IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Common Name' LIMIT 1)
);

-- Facility Ownership
INSERT INTO location_attribute
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Ownership' LIMIT 1),
    f.ownership,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.ownership IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Ownership' LIMIT 1)
);

-- Facility Type
INSERT INTO location_attribute
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Type' LIMIT 1),
    f.facility_type,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.facility_type IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Type' LIMIT 1)
);

-- Facility Status
INSERT INTO location_attribute
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Status' LIMIT 1),
    f.status,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.status IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Status' LIMIT 1)
);

-- Facility Regulatory Status
INSERT INTO location_attribute
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Regulatory Status' LIMIT 1),
    f.regulatory_status,
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.regulatory_status IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Regulatory Status' LIMIT 1)
);

-- Facility Date Opened
INSERT INTO location_attribute
    (location_id, attribute_type_id, value_reference, uuid, creator, date_created, voided)
SELECT
    flm.location_id,
    (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Date Opened' LIMIT 1),
    DATE_FORMAT(f.date_opened, '%Y-%m-%d'),
    UUID(),
    1,
    NOW(),
    0
FROM facilities f
INNER JOIN temp_facility_x_location_map flm ON f.code = flm.facility_code
WHERE f.date_opened IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM location_attribute la
    WHERE la.location_id = flm.location_id
    AND la.attribute_type_id = (SELECT location_attribute_type_id FROM location_attribute_type WHERE name = 'Facility Date Opened' LIMIT 1)
);

SELECT 'Location Attributes Created' AS status;

SELECT 'Migration Summary' AS info;
SELECT COUNT(*) AS total_facilities FROM facilities;
SELECT COUNT(*) AS mapped_facilities FROM temp_facility_x_location_map;
SELECT COUNT(*) AS location_attributes_created FROM location_attribute
WHERE attribute_type_id IN (
    SELECT location_attribute_type_id FROM location_attribute_type
    WHERE name LIKE 'Facility%'
);

SELECT 'Migration completed successfully!' AS status;

