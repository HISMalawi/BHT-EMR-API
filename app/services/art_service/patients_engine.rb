# frozen_string_literal: true

module ARTService
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
    def patient(patient_id)
      summarise_patient Patient.find(patient_id)
    end

    # Returns a patient's last received drugs.
    #
    # NOTE: This method is customised to return only ARVs.
    def patient_last_drugs_received(patient_id, ref_date: nil)
      ref_date = ref_date ? Date.strptime(ref_date) : Date.today

      dispensing_encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?
         AND DATE(encounter_datetime) <= DATE(?)',
        'DISPENSING', patient_id, ref_date
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

    def summarise_patient(patient)
      art_start_date, art_duration = patient_art_period(patient)
      {
        patient_id: patient.patient_id,
        npid: patient_identifier(patient, NPID_TYPE),
        arv_number: patient_identifier(patient, ARV_NO_TYPE),
        filing_number: patient_identifier(patient, FILING_NUMBER),
        current_outcome: patient_current_outcome(patient),
        residence: patient_residence(patient),
        art_duration: art_duration,
        current_regimen: patient_current_regimen(patient),
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
      Concept.find(obs.value_coded.to_i).concept_names[-1].name
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

      hiv_clinic_registration = Encounter.where([
        "encounter_type = ? AND patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)",
        EncounterType.find_by_name('HIV CLINIC REGISTRATION').id, patient_id,
        end_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date
      ]).last

      unless hiv_clinic_registration.blank?
        (hiv_clinic_registration.observations || []).map do |obs|
          concept_name = begin
                          obs.to_s.split(':')[0].strip
                         rescue StandardError
                           nil
                         end
          next if concept_name.blank?

          case concept_name
          when 'Date ART last taken'
            last_art_drugs_date_taken = begin
                                          obs.value_datetime.to_date
                                        rescue StandardError
                                          nil
                                        end
            unless last_art_drugs_date_taken.blank?
              days = ActiveRecord::Base.connection.select_value <<-EOF
                SELECT timestampdiff(
                  day, '#{last_art_drugs_date_taken.to_date}', '#{session_date.to_date}'
                ) AS days;
              EOF

              return 'Re-initiated' if days.to_i > 14
              return 'Continuing' if days.to_i <= 14
            end
          end
        end
      end

      dispensed_arvs = Observation.where([
        'person_id = ? AND concept_id = ? AND obs_datetime <= ?',
        patient_id, concept_id, end_date
      ]).map(&:value_drug)

      return 'Initiation' if dispensed_arvs.blank?

      arv_drug_concepts = MedicationService.arv_drugs.map(&:concept_id)
      arvs_found = ActiveRecord::Base.connection.select_all <<-EOF
        SELECT * FROM drug WHERE concept_id IN(#{arv_drug_concepts.join(',')})
        AND drug_id IN(#{dispensed_arvs.join(',')});
      EOF

      arvs_found.blank? == true ? 'Initiation' : 'Continuing'
    end
  end
end
