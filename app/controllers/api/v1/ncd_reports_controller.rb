module Api
  module V1
    class NcdReportsController < ApplicationController
      def ncd_active_patients
        filters = params.permit(%i[given_name middle_name family_name birthdate gender per_page page sync_to_mongo])
        @current_date = Date.current
        @location_id = User.current.location_id

        base_patients = Patient.joins(encounters: [:program, :type])
                              .where(program: { program_id: 32 })
                              .where(encounters: { location_id: @location_id })
                              .where(encounter_type: { name: ['PATIENT REGISTRATION', 'REGISTRATION'] })
                              .distinct

        if filters[:given_name].present? || filters[:family_name].present? || filters[:gender].present?
          filtered_patients = service.find_patients_by_name_and_gender(
            filters[:given_name], 
            filters[:middle_name], 
            filters[:family_name], 
            filters[:gender]
          )
          base_patients = base_patients.merge(filtered_patients)
        end

        base_patients = base_patients.joins(:person).where(person: { birthdate: filters[:birthdate] }) if filters[:birthdate].present?

        MongoSyncService.new.sync_patients_to_mongo(base_patients, @location_id)
        
        total_records = base_patients.count
        results = paginate(base_patients)

        render json: {
          count: total_records,
          results: results
        }, status: :ok
      end

      def ncd_active_patients_from_mongo
        filters = params.permit(%i[given_name middle_name family_name birthdate gender per_page page])
        @location_id = User.current.location_id

        # Build MongoDB query based on the actual document structure
        mongo_query = { location_id: @location_id.to_s }
        
        # Build MongoDB query based on the actual document structure
        mongo_query = { location_id: @location_id.to_s }

        # Add name filters - names are nested in active_patient.person.names array
        name_conditions = []

        if filters[:given_name].present?
          name_conditions << { "active_patient.person.names" => { "$elemMatch" => { "given_name" => /#{Regexp.escape(filters[:given_name])}/i } } }
        end

        # if filters[:family_name].present?
        #   name_conditions << { "active_patient.person.names" => { "$elemMatch" => { "family_name" => /#{Regexp.escape(filters[:family_name])}/i } } }
        # end

        if name_conditions.any?
          mongo_query["$and"] = name_conditions
        end

        # if filters[:middle_name].present?
        #   mongo_query["active_patient.person.names"] = { "$elemMatch" => { "middle_name" => /#{Regexp.escape(filters[:middle_name])}/i } }
        # end

        # # Gender filter
        # if filters[:gender].present?
        #   mongo_query["active_patient.person.gender"] = filters[:gender].upcase
        # end

        # Birthdate filter
        if filters[:birthdate].present?
          begin
            birthdate = Date.parse(filters[:birthdate])
            mongo_query["active_patient.person.birthdate"] = birthdate.strftime("%Y-%m-%d")
          rescue ArgumentError
            # Invalid date format, skip filter
          end
        end

        # Query MongoDB
        mongo_patients = NcdActivePatient.where(mongo_query)

        total_records = mongo_patients.count
        
        # Apply pagination
        page = filters[:page]&.to_i || 1
        per_page = filters[:per_page]&.to_i || 10
        
        results = mongo_patients.skip((page - 1) * per_page)
                              .limit(per_page)
                              .order_by(encounter_datetime: :desc)

        render json: {
          count: total_records,
          results: results.map(&:active_patient)
        }, status: :ok
      end

      private

      def service
        PatientService.new
      end
    end
  end
end