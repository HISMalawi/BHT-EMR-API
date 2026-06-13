# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class ArtDefaulterBatchPredictionJob
  include Sidekiq::Worker
  
  # Set reasonable concurrency options
  sidekiq_options queue: 'default', retry: 3

  def perform
    # 1. Query all active patients currently on ART.
    # Note: Using a simplified query for 'active ART patients' based on having an HIV program.
    # We limit to avoid massive payloads for this implementation.
    hiv_program = Program.find_by_name('HIV PROGRAM')
    return unless hiv_program

    patients = Patient.joins(:patient_programs)
                      .where(patient_programs: { program_id: hiv_program.id })
                      .distinct
                      .limit(500) # Process in batches of 500

    payload_patients = []
    
    # Pre-fetch concepts out of the loop
    side_effect_names = ['Drug side effect', 'ART side effect', 'Malaria severity', 'Symptom present']
    side_effect_concept = ConceptName.where(name: side_effect_names).first&.concept_id
    psych_concept = ConceptName.find_by_name('Mental status')&.concept_id
    appointment_concept_id = ConceptName.find_by_name('Appointment date')&.concept_id

    obs_model = defined?(Observation) ? Observation : Obs

    patients.each do |patient|
      # 2. Extract clinical data to match features
      age = patient.age.to_f || 30.0
      
      # Real clinical data extraction (6-month window from today)
      cutoff_date = Date.today
      start_window = cutoff_date - 6.months

      recent_encounters = patient.encounters.where(encounter_datetime: start_window.beginning_of_day..cutoff_date.end_of_day)
      recent_orders = patient.orders.where(start_date: start_window.beginning_of_day..cutoff_date.end_of_day)
      recent_obs = obs_model.where(person_id: patient.id, obs_datetime: start_window.beginning_of_day..cutoff_date.end_of_day)

      visit_count = recent_encounters.count.to_i
      side_effects = side_effect_concept ? recent_obs.where(concept_id: side_effect_concept).count.to_i : 0
      concurrent_drugs = recent_orders.count.to_i
      psychological_symptoms = psych_concept ? recent_obs.where(concept_id: psych_concept).count.to_i : 0

      days_overdue = 0.0
      if appointment_concept_id
        last_appointment = obs_model.where(person_id: patient.id, concept_id: appointment_concept_id)
                                    .where('obs_datetime <= ?', cutoff_date.end_of_day)
                                    .order(obs_datetime: :desc)
                                    .first
        if last_appointment&.value_datetime
          scheduled_return = last_appointment.value_datetime.to_date
          days_overdue = (cutoff_date - scheduled_return).to_f
        end
      end

      payload_patients << {
        patient_id: patient.id,
        age: age,
        visit_count: visit_count,
        side_effects: side_effects,
        concurrent_drugs: concurrent_drugs,
        psychological_symptoms: psychological_symptoms,
        days_overdue: days_overdue
      }
    end

    return if payload_patients.empty?

    # 3. Send payload in batches to Python Microservice
    uri = URI.parse('http://127.0.0.1:8000/predict/batch')
    header = { 'Content-Type': 'application/json' }
    request_body = { patients: payload_patients }

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = request_body.to_json

    begin
      response = http.request(request)
      if response.code.to_i == 200
        # 4. Update defaulter_risk_score in the database
        results = JSON.parse(response.body)['predictions']
        
        ActiveRecord::Base.transaction do
          results.each do |result|
            patient_id = result['patient_id']
            risk_score = result['risk_score']
            
            # Using update_columns to skip callbacks if not needed, or standard update
            Patient.where(patient_id: patient_id).update_all(
              defaulter_risk_score: risk_score,
              risk_assessed_at: Time.current
            )
          end
        end
        Rails.logger.info("Batch prediction successful for #{results.length} patients")
      else
        Rails.logger.error("Failed to fetch predictions. HTTP Status: #{response.code}, Body: #{response.body}")
      end
    rescue StandardError => e
      Rails.logger.error("Error connecting to ML service: #{e.message}")
      raise e # Allow Sidekiq to retry
    end
  end
end
