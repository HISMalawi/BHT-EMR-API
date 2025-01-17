# frozen_string_literal: true

module ArtService
  class IdsBuilder
    include ModelUtils
    include Reports::Pepfar::Utils
    attr_reader :report, :patient_id, :program_id, :site_id, :date, :complete, :end_date

    def initialize(patient_id:, program_id:, date:)
      @program_id = program_id
      @date = date.to_date
      @patient_id = patient_id
      @end_date = date
      @report = OpenStruct.new
      @site_id = Location.current_health_center&.id
    end

    # Builds the report data for a patient.
    #
    # This method fetches data for a patient, including demographics, appointments,
    # clinic visits, family planning, and lab orders. It returns a hash with the
    # patient's demographics and an array of visit data.
    def build
      patient = patient_data
      visit_breakdown

      report.table.merge(patient).as_json
    end

    private

    PROCEDURE_MAP = {
      "appointments" => :ids_appointments,
      "clinic_visits" => :ids_clinic_visits,
      "family_plannings" => :ids_family_plannings,
      "hiv_reception" => :ids_hiv_reception,
      "hypertension_management" => :ids_hypertension_management,
      "identifiers" => :ids_identifiers,
      "initial_clinical_registration" => :ids_initial_clinical_registration,
      "lab_orders" => :ids_lab_orders,
      "lab_test_results" => :ids_lab_results,
      "medication_adherences" => :ids_medication_adherences,
      "medication_dispensations" => :ids_medication_dispensations,
      "outcomes" => :ids_outcomes,
      "screening" => :ids_screening,
      "side_effects" => :ids_side_effects,
      "treatment" => :ids_treatment,
      "vitals" => :ids_vitals,
    }

    # @note This method calls all the individual methods that are used to fetch
    #       different types of data for a patient. It is called by the build
    #       method and is used to populate the report OpenStruct.
    def visit_breakdown
      PROCEDURE_MAP.each do |key, value|
        report[key] = ActiveRecord::Base.connection.select_all <<~SQL
                                                                 CALL #{value}(#{site_id}, #{patient_id}, '#{date}');
                                                               SQL
      end
    end

    # Fetches a patient's data, including demographics, address, phone number,
    # and identifier.
    #
    # This method fetches a patient's data from the database, including the
    # patient's demographics, address, phone number, and identifiers. It
    # returns a hash with the patient's data.
    #
    # @return [Hash] a hash with the patient's data
    def patient_data
      Patient.find_by(patient_id:).as_json(
        ignore: true,
        only: %w[date_created patient_id],
        include: {
          person: {
            only: %w[
              person_id birthdate gender birthdate_estimated dead death_date cause_of_death
              date_created
            ],
            include: {
              identifiers: {
                methods: [:identifier_type_name],
                only: %i[identifier identifier_type],
              },
            },
            methods: %i[address cell_phone_number],
          },
        },
      )
    end
  end
end
