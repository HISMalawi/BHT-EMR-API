class MongoSyncService
      # Method to sync patients to MongoDB
    def sync_patients_to_mongo(patients, location_id)
      @location_id = location_id
      puts "Syncing #{patients.count} patients to MongoDB..."
      
      patients.includes(:encounters, :person).find_each do |patient|
        begin
          latest_encounter = patient.encounters
                              .joins(:program)
                              .where(program: { program_id: 32 })
                              .where(location_id: @location_id)
                              .order(encounter_datetime: :desc)
                              .first
          
          # Add validation to ensure latest_encounter exists
          if latest_encounter.nil?
            Rails.logger.error "No encounters found for patient #{patient.patient_id}"
            next
          end

          patient_data = patient.as_json
          ncd_patient = NcdActivePatient.find_or_initialize_by(patient_id: patient.patient_id)

          ncd_patient.encounter_datetime = latest_encounter.encounter_datetime
          ncd_patient.location_id = @location_id.to_s
          ncd_patient.active_patient = patient_data
          ncd_patient.last_synced_at = Time.current
          
          unless ncd_patient.save
            Rails.logger.error "Failed to save patient #{patient.patient_id}: #{ncd_patient.errors.full_messages}"
          end
        rescue => e
          Rails.logger.error "Error syncing patient #{patient.patient_id}: #{e.message}\n#{e.backtrace.join("\n")}"
          # raise e # Re-raise the error to see it in development
        end
      end
    end
end