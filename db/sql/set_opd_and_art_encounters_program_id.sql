update encounter set program_id = 1 where encounter_type IN(6, 7, 9, 13, 25, 51, 52, 53, 54, 57, 66, 68);

update encounter set program_id = 14 where encounter_type NOT IN(6, 7, 9, 13, 25, 51, 52, 53, 54, 57, 66, 68, 10);