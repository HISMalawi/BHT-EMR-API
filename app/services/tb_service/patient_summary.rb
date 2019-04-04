# frozen_string_literal: true

module TBService
    # Provides various summary statistics for an TB patient
    class PatientSummary
      NPID_TYPE = 'National id'
      FILING_NUMBER = 'Filing number'
      ARCHIVED_FILING_NUMBER = 'Archived filing number'
  
      SECONDS_IN_MONTH = 2_592_000
  
      include ModelUtils
  
      attr_reader :patient
      attr_reader :date
  
      def initialize(patient, date)
        @patient = patient
        @date = date
      end
  
      def full_summary
        drug_start_date, drug_duration = drug_period
        {
          patient_id: patient.patient_id,
          npid: identifier(NPID_TYPE) || 'N/A', #OK
					filing_number: filing_number || 'N/A', #OK
					residence: residence, #OK
          drug_duration: drug_duration || 'N/A', #OK
					drug_start_date: drug_start_date&.strftime('%d/%m/%Y') || 'N/A', #OK 
				}
				
      end
  
      def identifier(identifier_type_name)
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name)
  
        PatientIdentifier.where(
          identifier_type: identifier_type.patient_identifier_type_id,
          patient_id: patient.patient_id
        ).first&.identifier
      end
  
      def residence
        address = patient.person.addresses[0]
        return 'N/A' unless address
  
        district = address.state_province || 'Unknown District'
        village = address.city_village || 'Unknown Village'
        "#{district}, #{village}"
      end
	
			#NOT COMPLETE
      def current_regimen
        patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
        quoted_date = ActiveRecord::Base.connection.quote(date.to_date)
  
        #  SET max_obs_datetime = (SELECT MAX(start_date) FROM orders o INNER JOIN obs ON obs.order_id = o.order_id INNER JOIN drug_order od ON od.order_id = o.order_id AND od.drug_inventory_id IN(SELECT * FROM arv_drug) AND obs.voided = 0 AND o.voided = 0 AND DATE(obs_datetime) <= DATE(my_date) WHERE obs.person_id = my_patient_id AND od.quantity > 0);
        #  SET @drug_ids := (SELECT GROUP_CONCAT(DISTINCT(d.drug_inventory_id) ORDER BY d.drug_inventory_id ASC) FROM drug_order d INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id INNER  JOIN orders o ON d.order_id = o.order_id AND d.quantity > 0 INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.encounter_type = 25 WHERE o.voided = 0 AND date(o.start_date) = DATE(max_obs_datetime) AND e.patient_id = my_patient_id order by ad.drug_id ASC);
        ActiveRecord::Base.connection.select_one(
          "SELECT patient_current_regimen(#{patient_id}, #{quoted_date}) as regimen"
        )['regimen'] || 'N/A'
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("Failed tor retrieve patient current regimen: #{e}:")
        'N/A'
      end
	
			#NOT COMPLETE
      def current_outcome 
        patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
        quoted_date = ActiveRecord::Base.connection.quote(date)
        program_id = Program.find_by(name: 'TB PROGRAM').program_id
        patient_state = PatientState.joins(`INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id 
                                            AND p.program_id = #{program_id} WHERE (patient_state.voided = 0 AND p.voided = 0 
                                            AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = #{patient_id}) 
                                            AND (patient_state.voided = 0) ORDER BY start_date DESC, patient_state.patient_state_id DESC, 
                                            patient_state.date_created DESC LIMIT 1`)
  
        #SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);

        #SET set_patient_state = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC LIMIT 1);

				#     ActiveRecord::Base.connection.select_one(
				#       "SELECT patient_outcome(#{patient_id}, #{quoted_date}) as outcome"
				#     )['outcome'] || 'UNKNOWN'
				#   rescue ActiveRecord::StatementInvalid => e
				#     Rails.logger.error("Failed tor retrieve patient current outcome: #{e}:")
				#     'UNKNOWN'

      end
  
      def drug_reason
        concept = concept('Reason for ART eligibility') #need to find a proper concept for this one
        return 'UNKNOWN' unless concept
  
        obs_list = Observation.where concept_id: concept.concept_id,
                                     person_id: patient.patient_id
        obs_list = obs_list.order(date_created: :desc).limit(1)
        return 'N/A' if obs_list.empty?
  
        obs = obs_list[0]
  
        reason_concept = Concept.find_by_concept_id(obs.value_coded.to_i)
        return 'N/A' unless reason_concept
  
        reason_concept\
          .concept_names\
          .where(concept_name_type: 'FULLY_SPECIFIED')\
          .first\
          .name
      end
  
      def drug_period #OK
        start_date = (recent_value_datetime('TB drug start date')\
                      || recent_value_datetime('Drug start date')\
                      || earliest_start_date_at_clinic)
  
        return [nil, nil] unless start_date
  
        duration = ((Time.now - start_date) / SECONDS_IN_MONTH).to_i # Round off to preceeding integer
        [start_date, duration] # Reformat date
      end
  
      # Returns the most recent value_datetime for patient's observations of the
      # given concept
      def recent_value_datetime(concept_name) #OK
        concept = ConceptName.find_by_name(concept_name)
        date = Observation.where(concept_id: concept.concept_id,
                                 person_id: patient.patient_id)\
                          .order(obs_datetime: :desc)\
                          .first\
                          &.value_datetime
        return nil if date.blank?
  
        date
      end
  
			#NOT COMPLETE
      def earliest_start_date_at_clinic
        patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
  
        #functions created in the database
        #SET date_started = (SELECT MIN(start_date) FROM patient_state s INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id WHERE s.voided = 0 AND s.state = 7 AND p.program_id = 1 AND p.patient_id = set_patient_id);
        row = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT earliest_start_date_at_clinic(#{patient_id}) as date
        SQL
  
        row['date']&.to_datetime
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("Failed to retrieve patient earliest_start_date_at_clinic: #{e}:")
        nil
      end
  
      def filing_number #OK
        filing_number = identifier(FILING_NUMBER)
        return { number: filing_number || 'N/A', type: FILING_NUMBER } if filing_number
  
        filing_number = identifier(ARCHIVED_FILING_NUMBER)
        return { number: filing_number, type: ARCHIVED_FILING_NUMBER } if filing_number
  
        { number: 'N/A', type: 'N/A' }
      end
    end
  end
  