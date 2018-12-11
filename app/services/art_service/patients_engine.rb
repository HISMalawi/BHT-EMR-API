# frozen_string_literal: true

module ARTService
  include ModelUtils

  # Patients sub service.
  #
  # Basically provides ART specific patient-centric functionality
  class PatientsEngine
    def initialize(program:)
      @program = program
    end

    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an ART application.
    def patient(patient_id, date)
      summarise_patient Patient.find(patient_id), date
    end

    # Returns a patient's last received drugs.
    #
    # NOTE: This method is customised to return only ARVs.
    def patient_last_drugs_received(patient, ref_date: nil)
      ref_date = ref_date ? Date.strptime(ref_date) : Date.today

      dispensing_encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?
         AND DATE(encounter_datetime) <= DATE(?)',
        'DISPENSING', patient.patient_id, ref_date
      ).order(encounter_datetime: :desc).first

      return [] unless dispensing_encounter

      # HACK: Group orders in a map first to eliminate duplicates which can
      # be created when a drug is scanned twice.
      (dispensing_encounter.observations.each_with_object({}) do |obs, drug_map|
        next unless obs.value_drug || drug_map.key?(obs.value_drug)

        order = obs.order
        next unless order.drug_order

        drug_map[obs.value_drug] = order.drug_order if order.drug_order.drug.arv?
      end).values
    end

    # Returns patient's ART start date at current facility
    def find_patient_date_enrolled(patient)
      order = Order.joins(:encounter, :drug_order)\
                   .where(encounter: { patient: patient },
                          drug_order: { drug: Drug.arv_drugs })\
                   .order(:start_date)\
                   .first

      order&.start_date&.to_date
    end

    # Returns patient's actual ART start date.
    def find_patient_earliest_start_date(patient, date_enrolled = nil)
      date_enrolled ||= find_patient_date_enrolled(patient)

      patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
      date_enrolled = ActiveRecord::Base.connection.quote(date_enrolled)

      result = ActiveRecord::Base.connection.select_one(
        "SELECT date_antiretrovirals_started(#{patient_id}, #{date_enrolled}) AS date"
      )

      result['date']&.to_date
    end

    def find_status(patient, date = Date.today)
      {
        status: patient_initiated(patient.patient_id, date)
      }
    end

    def find_next_available_arv_number
      current_arv_code = global_property('site_prefix').property_value
      type = PatientIdentifierType.find_by_name('ARV Number')
      current_arv_number_identifiers = PatientIdentifier.where(identifier_type: type)

      unless current_arv_number_identifiers.nil?
        assigned_arv_ids = current_arv_number_identifiers.collect do |identifier|
          Regexp.last_match(1).to_i if identifier.identifier =~ /#{current_arv_code}-ARV- *(\d+)/
        end.compact
      end

      next_available_number = nil

      if assigned_arv_ids.empty?
        next_available_number = 1
      else
        # Check for unused ARV idsV Suggest the next arv_id based on unused ARV
        # ids that are within 10 of the current_highest arv id. This makes sure
        # that we don't get holes unless we really want them and also means that our
        # suggestions aren't broken by holes
        # array_of_unused_arv_ids = (1..highest_arv_id).to_a - assigned_arv_ids
        assigned_numbers = assigned_arv_ids.sort

        possible_number_range = global_property('arv_number_range')&.property_value&.to_i || 100_000

        possible_identifiers = Array.new(possible_number_range) { |i| (i + 1) }
        next_available_number = (possible_identifiers - assigned_numbers).first
      end

      "#{current_arv_code} #{next_available_number}"
    end

    #function to check if an arv number already exists
    def arv_number_already_exists(arv_number)
      identifier_type = PatientIdentifierType.find_by_name('ARV Number')
      identifiers = PatientIdentifier.all.where(
        identifier: arv_number,
        identifier_type: identifier_type.id
      ).exists?
    end

    def all_patients(paginator: nil)
      # TODO: Retrieve all patients
      []
    end

    private

    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'
    FILING_NUMBER = 'Filing number'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    def summarise_patient(patient, date)
      art_start_date, art_duration = patient_art_period(patient)
      {
        patient_id: patient.patient_id,
        npid: patient_identifier(patient, NPID_TYPE),
        arv_number: patient_identifier(patient, ARV_NO_TYPE),
        filing_number: patient_identifier(patient, FILING_NUMBER),
        current_outcome: patient_current_outcome(patient),
        residence: patient_residence(patient),
        art_duration: art_duration,
        current_regimen: patient_current_regimen(patient, date),
        art_start_date: art_start_date,
        reason_for_art: patient_art_reason(patient)
      }
    end

    def patient_identifier(patient, identifier_type_name)
      identifier_type = PatientIdentifierType.find_by_name(identifier_type_name)
      return 'UNKNOWN' unless identifier_type

      identifiers = patient.patient_identifiers.where(
        identifier_type: identifier_type.patient_identifier_type_id
      )
      identifiers[0] ? identifiers[0].identifier : 'N/A'
    end

    def patient_residence(patient)
      address = patient.person.addresses[0]
      return 'N/A' unless address

      district = address.state_province || 'Unknown District'
      village = address.city_village || 'Unknown Village'
      "#{district}, #{village}"
    end

    def patient_current_regimen(patient, date = Date.today)
      patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
      date = ActiveRecord::Base.connection.quote(date)

      ActiveRecord::Base.connection.select_one(
        "SELECT patient_current_regimen(#{patient_id}, #{date}) as regimen"
      )['regimen'] || 'N/A'
    end

    def patient_current_outcome(patient)
      patient_program = PatientProgram.find_by patient_id: patient.patient_id,
                                               program_id: @program.program_id
      return 'UNKNOWN' unless patient_program

      program_states = ProgramWorkflowState.joins(:patient_states).where(
        'patient_state.patient_program_id = ?',
        patient_program.patient_program_id
      ).order('patient_state.date_created')

      return 'N/A' if program_states.empty?

      program_states[0].concept.concept_names[0].name
    end

    def patient_art_reason(patient)
      concept = concept('Reason for ART eligibility')
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

    def patient_art_period(patient)
      concept = concept('ART start date')
      return 'UNKNOWN', 'UNKNOWN' unless concept

      obs_list = Observation.where concept_id: concept.concept_id,
                                   person_id: patient.patient_id
      obs_list = obs_list.order(date_created: :desc).limit(1)
      obs = obs_list[0]
      return 'N/A', 'N/A' unless obs

      duration = (Time.now - obs.value_datetime) / SECONDS_IN_MONTH
      [obs.value_datetime.strftime('%d/%b/%y'), duration]
    end

    # source: NART/lib/patient_service#patient_initiated
    def patient_initiated(patient_id, session_date)
      ans = ActiveRecord::Base.connection.select_value <<-SQL
        SELECT re_initiated_check(#{patient_id}, '#{session_date.to_date}')
      SQL

      return ans if ans == 'Re-initiated'

      end_date = session_date.strftime('%Y-%m-%d 23:59:59')
      concept_id = ConceptName.find_by_name('Amount dispensed').concept_id

      hiv_clinic_registration = Encounter.where(
        'encounter_type = ? AND patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)',
        EncounterType.find_by_name('HIV CLINIC REGISTRATION').id, patient_id,
        end_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date
      ).last

      unless hiv_clinic_registration.blank?
        hiv_clinic_registration.observations.map do |obs|
          concept_name = obs.concept.concept_names.first.name

          next unless concept_name == 'Date ART last taken'

          last_art_drugs_date_taken = obs&.value_datetime&.to_date

          next unless last_art_drugs_date_taken

          days = ActiveRecord::Base.connection.select_value <<-SQL
                SELECT timestampdiff(
                  day, '#{last_art_drugs_date_taken}', '#{session_date.to_date}'
                ) AS days;
          SQL

          return days.to_i > 14 ? 'Re-initiated' : 'Continuing'
        end
      end

      dispensed_arvs = Observation.where(
        'person_id = ? AND concept_id = ? AND obs_datetime <= ?',
        patient_id, concept_id, end_date
      ).map(&:value_drug)

      return 'Initiation' if dispensed_arvs.empty?

      arv_drug_concepts = Drug.arv_drugs.map(&:concept_id)

      arvs_found = ActiveRecord::Base.connection.select_all <<-SQL
        SELECT * FROM drug WHERE concept_id IN(#{arv_drug_concepts.join(',')})
        AND drug_id IN(#{dispensed_arvs.join(',')});
      SQL

      arvs_found ? 'Continuing' : 'Initiation'
    end
  end
end
