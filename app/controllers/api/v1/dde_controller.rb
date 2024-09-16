# frozen_string_literal: true

module Api
  module V1
    class DdeController < ApplicationController
      # GET /api/v1/dde/patients
      def find_patients_by_npid
        npid = params.require(:npid)
        render json: service.find_patients_by_npid(npid)
      end

      def find_patients_by_name_and_gender
        given_name, family_name, gender = params.require(%i[given_name family_name gender])
        render json: service.find_patients_by_name_and_gender(given_name, family_name, gender)
      end

      def import_patients_by_npid
        npid = params.require(:npid)
        render json: service.import_patients_by_npid(npid)
      end

      def import_patients_by_doc_id
        doc_id = params.require(:doc_id)
        render json: service.import_patients_by_doc_id(doc_id)
      end

      def remaining_npids
        render json: service.remaining_npids
      end

      # GET /api/v1/dde/match
      #
      # Returns DDE patients matching demographics passed
      def match_patients_by_demographics
        render json: service.match_patients_by_demographics(**match_params)
      end

      def reassign_patient_npid
        patient_ids = params.permit(:doc_id, :patient_id)
        render json: service.reassign_patient_npid(patient_ids)
      end

      def merge_patients
        primary_patient_ids = params.require(:primary)
        secondary_patient_ids_list = params.require(:secondary)

        render json: service.merge_patients(primary_patient_ids, secondary_patient_ids_list)
      end

      def patient_diff
        patient_id = params.require(:patient_id)
        diff = service.find_patient_updates(patient_id)

        render json: { diff: }
      end

      ##
      # Updates local patient with demographics in DDE.
      def refresh_patient
        patient_id = params.require(:patient_id)
        update_npid = params[:update_npid]&.casecmp?('true') || false

        patient = service.update_local_patient(Patient.find(patient_id), update_npid:)

        render json: patient
      end

      def duplicates_finder
        # Get all patients along with the necessary attributes
        patients = Person.all
                         .joins("INNER JOIN person_name ON person_name.person_id = person.person_id")
                         .joins("INNER JOIN patient_program ON patient_program.patient_id = person.person_id")
                         .joins("INNER JOIN person_address ON person_address.person_id = person.person_id")
                         .where(patient_program: { program_id: 33, voided: 0 })
                         .select("person.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                                  person_name.given_name AS firstname, person_name.family_name AS sirname,
                                  person_address.address2 AS home_district, person_address.neighborhood_cell AS home_village,
                                  person_address.county_district AS home_traditional_authority")
                                  
        fuzzy_firstname_matcher = FuzzyMatch.new(patients.map(&:firstname))
        fuzzy_sirname_matcher = FuzzyMatch.new(patients.map(&:sirname))
        fuzzy_home_district_matcher = FuzzyMatch.new(patients.map(&:home_district))
        fuzzy_home_village_matcher = FuzzyMatch.new(patients.map(&:home_village))
        fuzzy_home_traditional_authority_matcher = FuzzyMatch.new(patients.map(&:home_traditional_authority))
                                
        duplicate_matches = []
        already_checked = Set.new 
      
        patients.each do |primary_patient|
          next if already_checked.include?(primary_patient.person_id)
      
          matches = []
      
          patients.each do |secondary_patient|
            next if primary_patient.person_id == secondary_patient.person_id || already_checked.include?(secondary_patient.person_id)
      
            match_percentage = 0
            match_percentage += 14.28 if fuzzy_firstname_matcher.find(primary_patient.firstname) == secondary_patient.firstname
            match_percentage += 14.28 if fuzzy_sirname_matcher.find(primary_patient.sirname) == secondary_patient.sirname
            match_percentage += 14.28 if fuzzy_home_district_matcher.find(primary_patient.home_district) == secondary_patient.home_district
            match_percentage += 14.28 if fuzzy_home_village_matcher.find(primary_patient.home_village) == secondary_patient.home_village
            match_percentage += 14.28 if fuzzy_home_traditional_authority_matcher.find(primary_patient.home_traditional_authority) == secondary_patient.home_traditional_authority
            
            match_percentage += 14.28 if primary_patient.birthdate == secondary_patient.birthdate
            match_percentage += 14.28 if primary_patient.gender == secondary_patient.gender
      
            if match_percentage.round(0) > 85
              matches << { 
                secondary_patient_id: secondary_patient.person_id,
                secondary_firstname: secondary_patient.firstname,
                secondary_sirname: secondary_patient.sirname,
                match_percentage: match_percentage.round(0)
              }
            end
          end
      
          if matches.any?
            duplicate_matches << {
              primary_patient_id: primary_patient.person_id,
              primary_firstname: primary_patient.firstname,
              primary_sirname: primary_patient.sirname,
              primary_birthdate: primary_patient.birthdate,
              primary_gender: primary_patient.gender,
              duplicates: matches
            }
      
            already_checked << primary_patient.person_id
            matches.each do |match|
              already_checked << match[:secondary_patient_id]
            end
          end
        end
      
        render json: duplicate_matches
      end

      private

      MATCH_PARAMS = %i[given_name family_name gender birthdate home_village
                        home_traditional_authority home_district].freeze

      def match_params
        MATCH_PARAMS.each_with_object({}) do |param, params_hash|
          raise "param #{param} is required" if params[param].blank?

          params_hash[param] = params[param]
        end
      end

      def service
        DdeService.new(program:)
      end

      def program
        Program.find(params.require(:program_id))
      end
    end
  end
end
