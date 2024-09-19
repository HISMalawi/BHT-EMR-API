# frozen_string_literal: true
require 'bantu_soundex'
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

      

    def duplicates_match

                results =  paginate(PotentialDuplicate.where(merge_status: 0))
                                                      .group_by(&:patient_id_a)
                                                      .map do |primary_patient_id, matches|

                  primary_patient = Person.joins("INNER JOIN person_name ON person_name.person_id = person.person_id")
                                          .joins("INNER JOIN person_address ON person_address.person_id = person.person_id")
                                          .select("person.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                                                   person_name.given_name AS firstname, person_name.family_name AS sirname,person_name.middle_name AS middlename")
                                          .find_by(person_id: primary_patient_id)

                  duplicates = matches.map do |match|
                     secondary_patient = Person.joins("INNER JOIN person_name ON person_name.person_id = person.person_id")
                                               .select("person.person_id AS person_id, person_name.given_name AS firstname, 
                                                          person_name.family_name AS sirname,person_name.middle_name AS middlename")
                                               .find_by(person_id: match.patient_id_b)

                               {
                                    secondary_patient_id: secondary_patient.person_id,
                                    secondary_firstname: secondary_patient.firstname,
                                    secondary_middlename: secondary_patient.middlename,
                                      secondary_sirname: secondary_patient.sirname,
                                       match_percentage: match.match_percentage
                                }
                  end

                               {
                                   primary_patient_id: primary_patient.person_id,
                                    primary_firstname: primary_patient.firstname,
                                   primary_middlename: primary_patient.middlename,
                                      primary_sirname: primary_patient.sirname,
                                    primary_birthdate: primary_patient.birthdate,
                                       primary_gender: primary_patient.gender,
                                           duplicates: duplicates
                              }
                  end

          render json: results, status: :ok
    end

    def duplicates_finder
      # Get all patients along with the necessary attributes          
      patients = paginate(
        Person.joins("INNER JOIN person_name ON person_name.person_id = person.person_id")
              .joins("INNER JOIN patient_program ON patient_program.patient_id = person.person_id")
              .joins("INNER JOIN person_address ON person_address.person_id = person.person_id")
              .where(patient_program: { program_id: 33, voided: 0 })
              .select("person.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                       person_name.given_name AS firstname, person_name.family_name AS sirname, person_name.middle_name AS middle_name,
                       person_address.address2 AS home_district, person_address.neighborhood_cell AS home_village,
                       person_address.county_district AS home_traditional_authority")
      )
    
      potential_duplicates = []
      already_checked = Set.new
      threshold_percent = YAML.safe_load(File.read(Rails.root.join('config', 'application.yml')))["matching_percent"]
    
      patients.each do |primary_patient|
        next if already_checked.include?(primary_patient.person_id)
    
        fuzzy_potential_duplicates = patients.select do |potential_duplicate|
          potential_duplicate.person_id != primary_patient.person_id &&
            !already_checked.include?(potential_duplicate.person_id) &&
            (WhiteSimilarity.similarity(primary_patient.to_s, potential_duplicate.to_s) * 100) > threshold_percent
        end
    
        soundex_potential_duplicates = patients.select do |client|
          perform_soundex_matching(primary_patient, client) == true && 
          !already_checked.include?(client.person_id)
        end
    
        all_potential_duplicates = (fuzzy_potential_duplicates + soundex_potential_duplicates).uniq
    
        final_potential_duplicates = all_potential_duplicates.select do |client|
          client.person_id != primary_patient.person_id && 
          (WhiteSimilarity.similarity(client.to_s, primary_patient.to_s) * 100) > threshold_percent
        end
    
        final_potential_duplicates.each { |match| already_checked << match.person_id }
        
        potential_duplicates << {
          primary_patient_id: primary_patient.person_id,
          primary_firstname: primary_patient.firstname,
          primary_sirname: primary_patient.sirname,
          primary_birthdate: primary_patient.birthdate,
          primary_gender: primary_patient.gender,
          duplicates: final_potential_duplicates.map do |match|
            {
              secondary_patient_id: match.person_id,
              secondary_firstname: match.firstname,
              secondary_sirname: match.sirname,
              match_percentage: (WhiteSimilarity.similarity(primary_patient.to_s, match.to_s) * 100).round(0)
            }
          end
        }
    
        already_checked << primary_patient.person_id
      end
        
      save_matching(potential_duplicates)
      render json: potential_duplicates, status: :ok
    end
    
      
    private

      def perform_soundex_matching(primary_patient, secondary_patient)
      
        names = PersonName.where(person_id: primary_patient.person_id)
        match_percentage = 0
        match_percentage += 5 if names.where('SOUNDEX(given_name) = SOUNDEX(?)', secondary_patient.firstname).exists?
        match_percentage += 5 if names.where('SOUNDEX(middle_name) = SOUNDEX(?)', secondary_patient.middle_name).exists?
        match_percentage += 5 if names.where('SOUNDEX(family_name) = SOUNDEX(?)', secondary_patient.sirname).exists?
        match_percentage >= 10
      end
      

      def save_matching(duplicate_matches)
        ActiveRecord::Base.transaction do
          duplicate_matches.each do |client|
            primary_patient_id = client[:primary_patient_id]
            
            client[:duplicates].each do |clientB|
              secondary_patient_id = clientB[:secondary_patient_id]
                  match_percentage = clientB[:match_percentage]
          
              match_exists = PotentialDuplicate.where(
                "(patient_id_a = :primary_id AND patient_id_b = :secondary_id) OR (patient_id_a = :secondary_id AND patient_id_b = :primary_id)",
                primary_id: primary_patient_id, secondary_id: secondary_patient_id
              ).exists?
      
              unless match_exists
                PotentialDuplicate.create!(
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
