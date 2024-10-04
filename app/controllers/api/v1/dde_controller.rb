# frozen_string_literal: true
require 'bantu_soundex'
module Api
  module V1
    class DdeController < ApplicationController

      MATCH_PARAMS = %i[given_name family_name gender birthdate home_village
                        home_traditional_authority home_district].freeze

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
        primary_patient_ids = params.require(:primary).permit(%i[patient_id doc_id])
        secondary_patient_ids_list = params.require(:secondary)
        result = nil

        ActiveRecord::Base.transaction do
          result = service.merge_patients(primary_patient_ids, secondary_patient_ids_list)
          update_merged_potential_duplicates(primary_patient_ids, secondary_patient_ids_list)
        end

        render json: result, status: :ok
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
        results = paginate(PotentialDuplicate.where(merge_status: false).select(:patient_id_a).distinct).map do |primary_patient_a|
          PotentialDuplicate.where(merge_status: false, patient_id_a: primary_patient_a.patient_id_a)
                                             .group_by(&:patient_id_a)
                                             .map do |primary_patient_id, matches|
            primary_patient = Person.joins('INNER JOIN person_name ON person_name.person_id = person.person_id')
                                    .joins('INNER JOIN person_address ON person_address.person_id = person.person_id')
                                    .select('person.person_id, person.birthdate, person.gender,
                                             person_name.given_name, person_name.family_name,
                                             person_name.middle_name, person_address.address2 AS home_district,
                                             person_address.neighborhood_cell AS home_village,
                                             person_address.county_district AS home_traditional_authority')
                                    .find_by(person_id: primary_patient_id)

            duplicates = matches.map do |match|
              secondary_patient = Person.joins('INNER JOIN person_name ON person_name.person_id = person.person_id')
                                        .joins('INNER JOIN person_address ON person_address.person_id = person.person_id')
                                        .select('person.person_id, person.birthdate, person.gender,
                                             person_name.given_name, person_name.family_name,
                                             person_name.middle_name, person_address.address2 AS home_district,
                                             person_address.neighborhood_cell AS home_village,
                                             person_address.county_district AS home_traditional_authority')
                                        .find_by(person_id: match.patient_id_b)

              {
                secondary_patient_id: secondary_patient.person_id,
                secondary_given_name: secondary_patient.given_name,
                secondary_middle_name: secondary_patient.middle_name,
                secondary_family_name: secondary_patient.family_name,
                secondary_home_district: secondary_patient.home_district,
                secondary_home_ta: secondary_patient.home_traditional_authority,
                secondary_home_village: secondary_patient.home_village,
                secondary_birthdate: secondary_patient.birthdate,
                secondary_gender: secondary_patient.gender,
                match_percentage: match.match_percentage
              }
            end

            {
              primary_patient_id: primary_patient.person_id,
              primary_given_name: primary_patient.given_name,
              primary_middle_name: primary_patient.middle_name,
              primary_family_name: primary_patient.family_name,
              primary_home_district: primary_patient.home_district,
              primary_home_ta: primary_patient.home_traditional_authority,
              primary_home_village: primary_patient.home_village,
              primary_birthdate: primary_patient.birthdate,
              primary_gender: primary_patient.gender,
              duplicates:
            }
        end
      end

        render json: results, status: :ok
      end

      def duplicates_finder
        global_duplicates = PotentialDuplicateFinderService.duplicates_finder
        render json: global_duplicates, status: :ok
      end


    private

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

      def update_merged_potential_duplicates(primary_patient_id, secondary_patient_ids)
        secondary_patient_ids.each do |secondary_patient_id|
          PotentialDuplicate.where(patient_id_a: primary_patient_id[:patient_id],
                                   patient_id_b: secondary_patient_id[:patient_id])
                            .or(PotentialDuplicate.where(patient_id_b: primary_patient_id[:patient_id],
                                                         patient_id_a: secondary_patient_id[:patient_id]))
                            .update_all(merge_status: true, updated_at: Time.now)
        end
      end
    end
  end
end
