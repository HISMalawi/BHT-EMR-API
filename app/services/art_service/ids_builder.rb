require "set"

module ArtService
  class IdsBuilder
    include ModelUtils
    include Reports::Pepfar::Utils
    attr_reader :report, :patient_id, :program_id, :date, :complete, :end_date

    def initialize(patient_id:, program_id:, date:)
      @program_id = program_id
      @date = date.to_date
      @patient_id = patient_id
      @end_date = date
      @report = OpenStruct.new
    end

    def build
      patient = patient_data
      visit_data = visit_breakdown

      report.table&.merge(patient)
    end

    private

    def visit_breakdown
      visit
      reception
      clinic_registration
      vitals
      staging
      consultation
      medication_and_adherence
      lab_orders
      htn_management
    end

    def visit
      hash = OpenStruct.new
      hash.visit_date = date
      hash.initial_visit = obs_value("Type of patient") == "New patient"
      hash.transfer_in = patient_history.transfer_in
      hash.outcome = patient_visit.outcome
      hash.outcome_date = patient_visit.outcome_date
      hash.date_enrolled = PatientsEngine.new(program: Program.find(program_id)).find_patient_earliest_start_date(Patient.find(patient_id))
      hash.date_completed = PatientProgram.find_by(patient_id: patient_id, program_id: program_id)&.date_completed

      report["visit"] = hash.table
    end

    def htn_management
      hash = OpenStruct.new
      hash.htn_client = HtnWorkflow.new.htn_client?(Patient.find(patient_id), date)
      hash.patient_has_hp = obs_value("Patient has hypertension")
      hash.date_diagnosed_hp = obs_value("Hypertension diagnosis date")
      hash.risk_factors = []
      hash.htn_drugs = PatientService.new.current_htn_drugs_summary(Patient.find(patient_id), date)

      report["htn_management"] = hash.table
    end

    def vitals
      hash = OpenStruct.new
      hash.height = patient_visit.height
      hash.weight = patient_visit.weight
      hash.temp = obs_value("Temperature")
      hash.bmi = patient_visit.bmi
      hash.systolic_bp = obs_value("Systolic blood pressure")
      hash.diastolic_bp = obs_value("Diastolic blood pressure")

      report["vitals"] = hash.table
    end

    def staging
      hash = OpenStruct.new
      hash.patient_pregnant = patient_history.pregnant
      hash.patient_breastfeeding = obs_value("Breast feeding?")
      hash.who_stages_presented = patient_history.who_clinical_conditions
      hash.who_stage = obs_value("WHO stage")
      hash.reason_for_starting_art = obs_value("Reason for ART eligibility")
      hash.recent_cd4_results_available = obs_value("CD4 count")&.present?
      hash.cd4_count = obs_value("CD4 count")
      hash.cd4_count_date = obs_value("Cd4 count datetime")
      hash.cd4_test_location = obs_value("CD4 count location")

      report["staging"] = hash.table
    end

    def consultation
      hash = OpenStruct.new
      hash.family_planning_method = obs_value("Family planning method")
      hash.family_planning_today = obs_value("Family planning, action to take")
      hash.reason_for_not_using_family_planning = obs_value("Why does the woman not use birth control")
      hash.side_effects = patient_visit.side_effects
      hash.on_tb_treatment = patient_on_tb_treatment?(patient_id)
      hash.tb_status = patient_visit.tb_status
      hash.date_started_tb_treatment = obs_value("TB treatment start date")
      hash.months_on_tb_treatment = obs_value("TB treatment period")
      hash.tpt_history = obs_value("Previous TB treatment history")
      hash.routine_tb_screening = obs_value("Routine TB screening")
      # hash.allegic_to_cotrimoxazole = obs_value("Allegic to cotrimoxazole")
      hash.medication_prescribed = RegimenEngine.new(program: program("HIV program")).find_dosages(patient: Patient.find(patient_id), date:)
      hash.medication_ordered = hash.medication_prescribed

      report["consultation"] = hash.table
    end

    def medication_and_adherence
      hash = OpenStruct.new
      hash.regimen_category = patient_summary.current_regimen
      hash.next_appointment = patient_visit.next_appointment
      hash.pills_brought_to_clinic = patient_visit.pills_brought
      hash.doses_missed = calculate_doses_missed
      hash.reason_for_poor_adherence = obs_value("Reason for poor treatment adherence")
      hash.agree_with_adherence = hash.reason_for_poor_adherence.present? ? "No" : "Yes"

      report["medication_and_adherence"] = hash.table
    end

    def lab_orders
      hash = OpenStruct.new
      hash.previous_lab_orders = Lab::OrdersSearchService.find_orders(patient_id:)
      report["lab_orders"] = hash.table
    end

    def reception
      hash = OpenStruct.new

      hash.type_of_patient = obs_value("Type of patient")
      hash.guardian_relationship_type = guardian_relationship_type
      hash.patient_present = obs_value("Patient present")
      hash.guardian_present = obs_value("Guardian present")
      hash.visit_type = obs_value("Visit type")
      hash.arv_number = patient_history.arv_number

      report["reception"] = hash.table
    end

    def clinic_registration
      hash = OpenStruct.new

      hash.agrees_to_followup = obs_value("Agrees to followup")
      hash.has_hts_linkage_number = obs_value("HTC Serial number")
      hash.ever_received_arv = obs_value("Ever received ART")
      hash.confirmatory_hiv_test = obs_value("Confirmatory hiv test type")
      hash.location_of_confirmatory_hiv_test = obs_value("Confirmatory HIV test location")
      hash.date_of_confirmatory_hiv_test = obs_value("Confirmatory HIV test date")

      report["clinic_registration"] = hash.table
    end

    def guardian_relationship_type
      Relationship.where(
        person_a: patient_id,
      ).last&.type&.b_is_to_a
    end

    def obs_children
      Observation
        .where("obs_datetime BETWEEN ? AND ?", date.to_date.beginning_of_day, date.to_date.end_of_day)
        .where(
          person_id: patient_id,
        )&.last&.children
    end

    def obs_value(indicator)
      concept_id = concept(indicator).concept_id

      Observation
        .where("obs_datetime BETWEEN ? AND ?", date.to_date.beginning_of_day, date.to_date.end_of_day)
        .where(
          person_id: patient_id,
          concept_id:,
        )&.last&.answer_string&.squish
    end

    def patient_data
      patient = Patient.find_by(patient_id:).as_json(
        ignore: true,
        only: %w[date_created patient_id],
        include: {
          person: {
            only: %w[
              birthdate gender birthdate_estimated dead death_date cause_of_death
              date_created
            ],
            include: {
              names: {
                only: [
                  :family_name, :given_name, :middle_name,
                ],
              },
              identifiers: {
                methods: [:identifier_type_name],
                only: [:identifier, :identifier_type],
              },
            },
            methods: [:preferred_address, :cell_phone_number],
          },
        },
      )

      patient['address'] ||= {}
      address = patient['person'].delete('preferred_address')

      patient['name'] = patient['person'].delete('names')&.first

      patient["address"]["current_district"] =  address["state_province"]
      patient["address"]["current_village"] = address["city_village"]
      patient["address"]["current_traditional_authority"] = address["township_division"]
      patient["address"]["home_district"] = address["address2"]
      patient["address"]["home_village"] = address["neighborhood_cell"]
      patient["address"]["home_traditional_authority"] = address["county_district"]

      patient["guardian"] = patient_history.guardian

      patient
    end

    def patient_visit
      PatientVisit.new(Patient.find(patient_id), date)
    end

    def patient_history
      PatientHistory.new(Patient.find(patient_id), date)
    end

    def mastercard
      PatientMastercard.new(Patient.find(patient_id), date)
    end

    def patient_summary
      PatientSummary.new(Patient.find(patient_id), date)
    end

    def calculate_doses_missed
      last_visit = PatientService.new.fetch_previous_visit(date, patient_id, program_id)

      return 0 unless last_visit

      prev_pills = PatientVisit.new(Patient.find(patient_id), last_visit).pills_dispensed

      # const timeUnit = d.frequency === "QW" ? "week" : "day"
      # const daysGone = calcTimeElapsed(d.order.start_date, timeUnit)
      # (d.quantity - (daysGone * d.equivalent_daily_dose))
    end

    def fetch_patient_orders
      LabTestsEngine.new(program: program("HIV program")).find_orders_by_patient(patient_id)
    end
  end
end
