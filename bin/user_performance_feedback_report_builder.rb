User.current = User.first

Session_date = Date.today
@start_date = Session_date.strftime('%Y-%m-%d 00:00:00')
@end_date = Session_date.strftime('%Y-%m-%d 23:59:59')

Location.current = Location.find(725)

Patient_visit_concept_name = ConceptName.find_by_name('Patient present')
Guardian_visit_concept_name = ConceptName.find_by_name('Guardian present')
YesConcept = ConceptName.find_by_name('Yes')
NoConcept = ConceptName.find_by_name('No')
Prescribe_meds = ConceptName.find_by_name('Prescribe drugs')
FastConcept = ConceptName.find_by_name('FAST')

	hiv_encounter_types = ['HIV RECEPTION','HIV STAGING','VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
    'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

	HIV_encounter_ids = EncounterType.where("name IN(?)", hiv_encounter_types).map(&:id)


@selected_activities = {} 

def notification_tracker_user_activities

	activities = ActiveRecord::Base.connection.select_all <<~SQL
	SELECT * FROM notification_tracker_user_activities 
	WHERE login_datetime <= '#{@end_date}';
SQL

	activities.each do |a|
		user_id = a['user_id'].to_i
	  login_datetime = a['login_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')	

		if @selected_activities[user_id].blank?
			@selected_activities[user_id] = {}
		end

		if @selected_activities[user_id][login_datetime].blank?
			@selected_activities[user_id][login_datetime] = []
		end

		@selected_activities[user_id][login_datetime] = a['selected_activities'].split('##')
	end unless activities.blank?

end



def start
	notification_tracker_user_activities

  build_temp_tables

  dates = ((Session_date - 4.day).to_date..(Session_date)).map{ |date| date }

  (dates).each do |d|
    @start_date = d.strftime('%Y-%m-%d 00:00:00')
    @end_date   = d.strftime('%Y-%m-%d 23:59:59')
	  fetch_patient_seen
	  fetch_overall_record_complete_status


	  fetch_individual_record_complete_status
		build_provider_patient_interactions
		build_individual_record_complete_status
  end
end

def fetch_overall_record_complete_status
	all_patients = ActiveRecord::Base.connection.select_all <<~SQL
		SELECT * FROM patient_seen WHERE visit_date = '#{@start_date.to_date}';
SQL


	(all_patients || []).each do |r|
		patient_id = r['patient_id'].to_i
		visit_date = r['visit_date'].to_date

		#patient_visit = Observation.find(:last, :conditions =>["person_id = ? 
		#	AND obs_datetime BETWEEN ? AND ? AND concept_id = ? AND value_coded = ?",
		#	patient_id, StartDate, EndDate, 
		#	Patient_visit_concept_name.concept_id, YesConcept.concept_id]).blank? != true

		skipped_encounter_type = check_for_skipped_encounter(patient_id, visit_date)

		puts "#{visit_date} ################################### #{skipped_encounter_type.name}"
		unless skipped_encounter_type.name.blank?
  		ActiveRecord::Base.connection.execute <<~SQL
				INSERT INTO overall_record_complete_status (patient_seen_id, complete)
 				VALUES(#{r['patient_seen_id']}, 0)
SQL

		end
		#raise complete.inspect
	end

end

def check_for_skipped_encounter(patient_id, visit_date)
  @start_date = visit_date.strftime('%Y-%m-%d 00:00:00')
  @end_date   = visit_date.strftime('%Y-%m-%d 23:59:59')
	return check_visit_completeness(patient_id)
end

def fetch_patient_seen
	hiv_encounter_types = ['HIV RECEPTION','HIV STAGING','VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
    'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

	encounter_ids = EncounterType.where("name IN(?)", hiv_encounter_types).map(&:id)

  ActiveRecord::Base.connection.execute <<~SQL
    INSERT INTO patient_seen (patient_id, visit_date) 
			SELECT DISTINCT(patient_id) patient_id, DATE(encounter_datetime) visit_date FROM
			encounter WHERE encounter_datetime BETWEEN '#{@start_date}'
			AND '#{@end_date}' AND voided = 0
      AND encounter_type IN(#{encounter_ids.join(',')})
			ORDER BY patient_id;
SQL

	
end

def build_temp_tables
  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `patient_seen`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `patient_seen` (
 		`patient_seen_id` int(11) NOT NULL AUTO_INCREMENT,
 		`patient_id` int(11) NOT NULL,
 		`visit_date` date NOT NULL,
		 PRIMARY KEY (`patient_seen_id`)
	 );
SQL

	puts "Created patient_seen ...."

  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `provider_record_complete_status`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `provider_record_complete_status` (
 		`id` int(11) NOT NULL AUTO_INCREMENT,
 		`patient_seen_id` int(11) NOT NULL,
 		`provider_id` int(11) NOT NULL,
 		`complete` SMALLINT(6) NOT NULL DEFAULT 0,
		 PRIMARY KEY (`id`),
 		 UNIQUE KEY `ID_UNIQUE` (`id`)
	 );
SQL

	puts "Created provider_record_complete_status ...."

  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `overall_record_complete_status`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `overall_record_complete_status` (
 		`id` int(11) NOT NULL AUTO_INCREMENT,
 		`patient_seen_id` int(11) NOT NULL,
 		`complete` SMALLINT(6) NOT NULL DEFAULT 0,
		 PRIMARY KEY (`id`),
 		 UNIQUE KEY `ID_UNIQUE` (`id`)
	 );
SQL

	puts "Created overall_record_complete_status ...."

	###############################################################

  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `providers_who_interacted_with_patients`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `providers_who_interacted_with_patients` (
 		`pi_id` int(11) NOT NULL AUTO_INCREMENT,
 		`user_id` int(11) NOT NULL,
 		`visit_date` date NOT NULL,
		 PRIMARY KEY (`pi_id`),
 		 UNIQUE KEY `ID_UNIQUE` (`pi_id`)
	 );
SQL

	puts "Created providers_who_interacted_with_patients ...."


  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `provider_patient_interactions`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `provider_patient_interactions` (
 		`ppi_id` int(11) NOT NULL AUTO_INCREMENT,
 		`pi_id` int(11) NOT NULL,
 		`patient_id` int(11) NOT NULL,
		 PRIMARY KEY (`ppi_id`),
 		 UNIQUE KEY `ID_UNIQUE` (`ppi_id`)
	 );
SQL

	puts "Created provider_patient_interactions ...."


  ActiveRecord::Base.connection.execute <<~SQL
    DROP TABLE IF EXISTS `encounters_missed`;
SQL

  ActiveRecord::Base.connection.execute <<~SQL
   CREATE TABLE IF NOT EXISTS `encounters_missed` (
 		`missed_encounter_id` int(11) NOT NULL AUTO_INCREMENT,
 		`ppi_id` int(11) NOT NULL,
 		`missed_encounter_type_id` int(11) NOT NULL,
 		`user_activities_id` int(11) NOT NULL,
		 PRIMARY KEY (`missed_encounter_id`),
 		 UNIQUE KEY `ID_UNIQUE` (`missed_encounter_id`)
	 );
SQL

	puts "Created encounters_missed ...."

end



#/////////////////////////////////////////////////////////////////////


def check_visit_completeness(patient_id, check_all_encounters = false)

  all_encounters_missed = []

  ############## no.1 HIV clinic registration ##################################
  encounter_type = EncounterType.find_by_name('HIV clinic registration')
  hiv_clinic_registration = Encounter.where("encounter_type = ? 
    AND patient_id = #{patient_id}", encounter_type.id).last

  if hiv_clinic_registration.blank?
    all_encounters_missed << encounter_type
    return encounter_type unless check_all_encounters
  end


  encounter_type = EncounterType.find_by_name('HIV STAGING')
  hiv_staging = Encounter.where("encounter_type = ? 
    AND patient_id = #{patient_id}", encounter_type.id).last

  if hiv_staging.blank?
    all_encounters_missed << encounter_type
    return encounter_type unless check_all_encounters
  end
  ####################################################################









  ############## no.2 HIV reception ##################################
  encounter_type = EncounterType.find_by_name('HIV Reception')
  hiv_reception = Encounter.where("encounter_type = ? AND encounter_datetime
    BETWEEN '#{@start_date}' AND '#{@end_date}' 
    AND patient_id = #{patient_id}", encounter_type.id).last

  if hiv_reception.blank?
    all_encounters_missed << encounter_type
    return encounter_type unless check_all_encounters
  end

  patient_visit = Observation.where("person_id = ? 
  	AND obs_datetime BETWEEN ? AND ? AND concept_id = ? AND value_coded = ?",
  	patient_id, @start_date, @end_date, 
  	Patient_visit_concept_name.concept_id, YesConcept.concept_id).last
  
  patient_visit = patient_visit.blank? ? false : true
  ####################################################################


	############################### chacking for fast track ##################
  latest_fast_track_answer_obs = Observation.where("person_id = ? 
  	AND obs_datetime < ? AND concept_id = ?", patient_id, @start_date, 
		FastConcept.concept_id).last

	fast_track_patient = false
	unless latest_fast_track_answer_obs.blank?
		latest_fast_track_answer = latest_fast_track_answer_obs.to_s.split(':')[1].squish.upcase 
		fast_track_patient = true if latest_fast_track_answer == 'YES'
	end
	############################### chacking for fast track end ##################
		




  ############## no.3 Vitals ##################################
  if patient_visit
    encounter_type = EncounterType.find_by_name('Vitals')
    hiv_reception = Encounter.where("encounter_type = ? AND encounter_datetime
      BETWEEN '#{@start_date}' AND '#{@end_date}' 
      AND patient_id = #{patient_id}", encounter_type.id).last

    if hiv_reception.blank?
      all_encounters_missed << encounter_type
      return encounter_type unless check_all_encounters
    end
  end unless fast_track_patient
  ####################################################################







  ############## no.4 HIV CLINIC CONSULTATION ##################################
  unless fast_track_patient
		encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
		hiv_clinic_cons = Encounter.where("encounter_type = ? AND encounter_datetime
			BETWEEN '#{@start_date}' AND '#{@end_date}' 
			AND patient_id = #{patient_id}", encounter_type.id).last

		if hiv_clinic_cons.blank?
      all_encounters_missed << encounter_type
      return encounter_type unless check_all_encounters
		end

		prescribe_meds = Observation.where("person_id = ? 
			AND obs_datetime BETWEEN ? AND ? AND concept_id = ? AND value_coded = ?",
			patient_id, @start_date, @end_date, 
			Prescribe_meds.concept_id, YesConcept.concept_id).blank? != true
		
	end
  ####################################################################


  ############## no.4.5 ART ADHERENCE ##################################
  encounter_type = EncounterType.find_by_name('ART ADHERENCE')
	adherence_encounter_available = Encounter.where("patient_id = ? AND encounter_type = ? 
		AND encounter_datetime BETWEEN ? AND ?",
		patient_id, encounter_type.id, @start_date, @end_date).order('encounter_datetime DESC,date_created DESC').last

	arv_drugs_given = false
	patient_arv_prescriptions(Patient.find(patient_id), @start_date.to_date).each do |order|
		arv_drugs_given = true
		break
	end

	if arv_drugs_given and adherence_encounter_available.blank?
    all_encounters_missed << encounter_type
    return encounter_type unless check_all_encounters
	end
	####################################################################



  if prescribe_meds
    ############## no.5 TREATMENT ##################################
    encounter_type = EncounterType.find_by_name('TREATMENT')
    treatment = Encounter.where("encounter_type = ? AND encounter_datetime
      BETWEEN '#{@start_date}' AND '#{@end_date}' 
      AND patient_id = #{patient_id}", encounter_type.id).last

    if treatment.blank?
      all_encounters_missed << encounter_type
      return encounter_type unless check_all_encounters
    end
    ####################################################################


    ############## no.6 DISPENSING ##################################
    encounter_type = EncounterType.find_by_name('DISPENSING')
    dispensing = Encounter.where("encounter_type = ? AND encounter_datetime
      BETWEEN '#{@start_date}' AND '#{@end_date}' 
      AND patient_id = #{patient_id}", encounter_type.id).last

    if dispensing.blank?
      all_encounters_missed << encounter_type
      return encounter_type unless check_all_encounters
    end
    ####################################################################


    ############## no.7 APPOINTMENT ##################################
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    appointment = Encounter.where("encounter_type = ? AND encounter_datetime
      BETWEEN '#{@start_date}' AND '#{@end_date}' 
      AND patient_id = #{patient_id}", encounter_type.id).last

    if appointment.blank?
      all_encounters_missed << encounter_type
      return encounter_type unless check_all_encounters
    end
    ####################################################################
  end

  if check_all_encounters
    return all_encounters_missed
  else
    return EncounterType.new()
  end
end

def fetch_individual_record_complete_status
	hiv_encounter_types = ['HIV RECEPTION','HIV STAGING','VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
    'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

	encounter_ids = EncounterType.where("name IN(?)", hiv_encounter_types).map(&:id)

  ActiveRecord::Base.connection.execute <<~SQL
    INSERT INTO providers_who_interacted_with_patients (user_id, visit_date) 
			SELECT DISTINCT(e.creator) user_id, DATE(encounter_datetime) visit_date 
      FROM patient_seen s  
      INNER JOIN encounter e ON s.patient_id = e.patient_id 
      WHERE e.encounter_datetime BETWEEN '#{@start_date}'
			AND '#{@end_date}' AND e.encounter_type IN(#{encounter_ids.join(',')})
      AND s.visit_date = '#{@start_date.to_date}' AND e.voided = 0
			ORDER BY e.creator;
SQL

end

def build_provider_patient_interactions

	providers = ActiveRecord::Base.connection.select_all <<~SQL
	SELECT DISTINCT(user_id) FROM providers_who_interacted_with_patients 
	WHERE visit_date = '#{@start_date.to_date}';
SQL

	(providers || []).each do |p|
		user_id = p['user_id'].to_i

  	ActiveRecord::Base.connection.execute <<~SQL
    	INSERT INTO provider_patient_interactions (patient_id, pi_id) 
				SELECT DISTINCT(e.patient_id), t.pi_id FROM providers_who_interacted_with_patients t
				INNER JOIN encounter e ON e.creator = t.user_id
				AND e.voided = 0 WHERE visit_date = '#{@start_date.to_date}'
				AND e.creator = #{user_id} AND e.encounter_type IN(#{HIV_encounter_ids.join(',')})
				AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
				AND e.patient_id IN(
					SELECT patient_id FROM overall_record_complete_status WHERE complete = 0
				)
				ORDER BY e.patient_id;
SQL

		puts ".... #{user_id} >> #{@start_date.to_date}"
	end

end

def build_individual_record_complete_status

	provider_patient_interactions = ActiveRecord::Base.connection.select_all <<~SQL
  SELECT i.ppi_id, t2.visit_date, user_id, s.patient_id FROM overall_record_complete_status t
  INNER JOIN patient_seen s on s.patient_seen_id = t.patient_seen_id
  INNER JOIN provider_patient_interactions i ON i.patient_id = s.patient_id
  INNER JOIN providers_who_interacted_with_patients t2 ON t2.pi_id = i.pi_id;
SQL

	(provider_patient_interactions || []).each do |i|
		ppi_id 			= i['ppi_id'].to_i
		patient_id 	= i['patient_id'].to_i
		visit_date 	= i['visit_date'].to_date
		user_id 	  = i['user_id'].to_i

		@start_date = visit_date.strftime('%Y-%m-%d 00:00:00')
		@end_date   = visit_date.strftime('%Y-%m-%d 23:59:59')

	  all_missed_encounters =  check_visit_completeness(patient_id, true)

    data = select_user_missed_activities(user_id, all_missed_encounters, @start_date)
     
		missed_encounter_type_ids = data[0]
    user_activities_id = data[1]

    (missed_encounter_type_ids || []).each do |e| 
		  ActiveRecord::Base.connection.execute <<~SQL
    	  INSERT INTO encounters_missed (ppi_id, missed_encounter_type_id, user_activities_id)
			  VALUES (#{ppi_id}, #{e.id}, #{user_activities_id}); 
SQL

      puts "Individual record complete status: #{user_activities_id}"
    end unless user_activities_id.blank?
		
	end
	
end


def select_user_missed_activities(user_id, encounter_types, start_date)
  activities = ActiveRecord::Base.connection.select_one <<~SQL
  SELECT * FROM notification_tracker_user_activities
  WHERE user_id = #{user_id} AND login_datetime >= '#{start_date}'
  ORDER BY login_datetime ASC;
SQL

  return [encounter_types, nil] if activities.blank?

  missed_encounter_types = []
=begin
Manage ART adherence##Manage HIV clinic consultations##Manage HIV first visits##Manage HIV reception visits##Manage HIV staging visits##Manage Appointments##Manage Drug Dispensations##Manage Prescriptions##Manage Vitals
=end

  encounter_types.each do |e|
    activities['selected_activities'].split('##').each do |activity|
      
      if activity.match(/adherence/i) && e.name.match(/ADHERENCE/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/consultations/i) && e.name.match(/consultations/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/first visits/i) && e.name.match(/clinic registration/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/hiv reception/i) && e.name.match(/hiv reception/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/hiv staging/i) && e.name.match(/hiv staging/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/Manage appointment/i) && e.name.match(/appointment/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/Manage drug Dispensations/i) && e.name.match(/DISPENSING/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/Prescriptions/i) && e.name.match(/TREATMENT/i)
        missed_encounter_types << e
        break
      end

      if activity.match(/Vitals/i) && e.name.match(/VITALS/i)
        missed_encounter_types << e
        break
      end


    end
  end

  return [missed_encounter_types, (activities['id'].to_i rescue nil)]
end

def patient_arv_prescriptions(patient, date)
  encounter_type_id = EncounterType.find_by_name('TREATMENT').encounter_type_id
  arv_drug_concepts = Drug.arv_drugs.map(&:concept_id)

  Order.joins(
    'INNER JOIN drug_order ON drug_order.order_id = orders.order_id
     INNER JOIN encounter ON encounter.encounter_id = orders.encounter_id
     INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id'
  ).where(
    'encounter.encounter_type = ? AND encounter.patient_id = ?
     AND DATE(encounter.encounter_datetime) = DATE(?)
     AND drug.concept_id IN (?)',
    encounter_type_id, patient.patient_id, date, arv_drug_concepts
  ).order('encounter.encounter_datetime')
end


start

