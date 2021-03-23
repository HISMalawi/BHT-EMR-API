DELETE FROM `encounter_type` WHERE name in ("ANC TREATMENT", "ANC DISPENSING");

INSERT INTO `encounter_type` (name, description, creator, date_created,uuid) VALUES ('ANC TREATMENT','Treatment for Antenatal Clinic',1,'2019-04-29 10:21:01', '13b2dab3-6a58-11e9-8dd5-b46bfc6ad006'),('ANC DISPENSING','Dispensation for Antenatal Clinic',1,'2019-04-29 13:17:21', '5f2472ac-6a70-11e9-8dd5-b46bfc6ad006')
