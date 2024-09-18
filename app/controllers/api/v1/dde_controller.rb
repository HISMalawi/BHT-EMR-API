# frozen_string_literal: true
require 'text'
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
                            person_name.given_name AS firstname, person_name.family_name AS sirname,person_name.middle_name AS middle_name,
                            person_address.address2 AS home_district, person_address.neighborhood_cell AS home_village,
                            person_address.county_district AS home_traditional_authority")
  
        duplicate_matches = []
        already_checked = Set.new

        patients.each do |primary_patient|
        next if already_checked.include?(primary_patient.person_id)

           matches = []
           patients.each do |secondary_patient|
             next if primary_patient.person_id == secondary_patient.person_id || already_checked.include?(secondary_patient.person_id)

             # Perform two objects matching of the two objects
              match_percentage = perform_fuzzy_soundex_matching(primary_patient, secondary_patient)

             if match_percentage.round(0) > 20
                  matches << {
                    secondary_patient_id: secondary_patient.person_id,
                   secondary_firstname: secondary_patient.firstname,
                   secondary_sirname: secondary_patient.sirname,
                   match_percentage: match_percentage.round(0)}
              end
          end

              if matches.any?
                  duplicate_matches << {
                      primary_patient_id: primary_patient.person_id,
                      primary_firstname: primary_patient.firstname,
                      primary_sirname: primary_patient.sirname,
                      primary_birthdate: primary_patient.birthdate,
                      primary_gender: primary_patient.gender,
                          duplicates: matches }

                   already_checked << primary_patient.person_id
                  matches.each do |match|
                     already_checked << match[:secondary_patient_id]
                  end
                end
           end
         
        #duplicates = save_matching(duplicate_matches)
        render json: duplicate_matches, status: :ok
      end

      def duplicates_match
        
                matches = PatientMatch.where(merge_status: 0)
        grouped_matches = matches.group_by(&:patient_id_a)
      
             results = grouped_matches.map do |primary_patient_id, matches|

              primary_patient = Person.joins("INNER JOIN person_name ON person_name.person_id = person.person_id")
                                      .joins("INNER JOIN person_address ON person_address.person_id = person.person_id")
                                      .select("person.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                                               person_name.given_name AS firstname, person_name.family_name AS sirname")
                                      .find_by(person_id: primary_patient_id)
      
          duplicates = matches.map do |match|

            secondary_patient = PersonName.find_by_person_id(match.patient_id_b)
            {
              secondary_patient_id: secondary_patient.person_id,
              secondary_firstname: secondary_patient.given_name,
              secondary_sirname: secondary_patient.family_name,
              match_percentage: match.match_percentage
            }
          end

          {
            primary_patient_id: primary_patient.person_id,
            primary_firstname: primary_patient.firstname,
            primary_sirname: primary_patient.sirname,
            primary_birthdate: primary_patient.birthdate,
            primary_gender: primary_patient.gender,
            duplicates: duplicates
          }
        end
      
        render json: results, status: :ok
      end
      

      private

      def perform_fuzzy_soundex_matching(primary_patient, secondary_patient)

         match_percentage = 0

         primary_patient_str = [
          primary_patient.firstname,
          primary_patient.middle_name,
          primary_patient.sirname,
          primary_patient.gender,
          primary_patient.birthdate,
          primary_patient.home_district,
          primary_patient.home_village,
          primary_patient.home_traditional_authority
        ].join(' ')
      
        secondary_patient_str = [
          secondary_patient.firstname,
          secondary_patient.middle_name,
          secondary_patient.sirname,
          secondary_patient.gender,
          secondary_patient.birthdate,
          secondary_patient.home_district,
          secondary_patient.home_village,
          secondary_patient.home_traditional_authority
        ].join(' ')
      
        similarity_score = WhiteSimilarity.similarity(primary_patient_str, secondary_patient_str)
        # Add points for whitesimilarity matches (up to a maximum of 85)
        white_similarity_score = (similarity_score * 85).round(2) 

        soundex_score = 0
        # Add points for Soundex matches (up to a maximum of 15)
        soundex_score += 5 if Text::Soundex.soundex(primary_patient.firstname) == Text::Soundex.soundex(secondary_patient.firstname)
        soundex_score += 5 if Text::Soundex.soundex(primary_patient.middle_name) == Text::Soundex.soundex(secondary_patient.middle_name)
        soundex_score += 5 if Text::Soundex.soundex(primary_patient.sirname) == Text::Soundex.soundex(secondary_patient.sirname)

        # Combine WhiteSimilarity score and Soundex score, capping at 100%
         match_percentage = white_similarity_score + soundex_score
         match_percentage = [match_percentage, 100].min

         match_percentage

      end

      def save_matching(duplicate_matches)
        ActiveRecord::Base.transaction do
          duplicate_matches.each do |client|
            primary_patient_id = client[:primary_patient_id]
            
            client[:duplicates].each do |clientB|
              secondary_patient_id = clientB[:secondary_patient_id]
                  match_percentage = clientB[:match_percentage]
          
              match_exists = PatientMatch.where(
                "(patient_id_a = :primary_id AND patient_id_b = :secondary_id) OR (patient_id_a = :secondary_id AND patient_id_b = :primary_id)",
                primary_id: primary_patient_id, secondary_id: secondary_patient_id
              ).exists?
      
              unless match_exists
                PatientMatch.create!(
                  patient_id_a: primary_patient_id,
                  patient_id_b: secondary_patient_id,
                  match_percentage: match_percentage,
                )
              end
            end
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Failed to save patient match: #{e.message}")
      end
      
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
