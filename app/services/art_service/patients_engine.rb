# frozen_string_literal: true

module ArtService
  # Patients sub service.
  #
  # Basically provides ART specific patient-centric functionality
  class PatientsEngine
    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'
    FILING_NUMBER = 'Filing number'
    ARCHIVED_FILING_NUMBER = 'Archived filing number'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    def initialize(program: nil)
      @program = program || Program.find_by_name!('HIV Program')
    end

    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an ART application.
    def patient(patient_id, date)
      patient_summary(Patient.find(patient_id), date).full_summary
    end

    ##
    # Retrieves a patient's visit summary for a given date
    def patient_visit_summary(patient_id, date)
      PatientVisit.new(Patient.find(patient_id), date)
    end

    # Returns a patient's last received drugs.
    #
    # NOTE: This method is customised to return only ARVs.
    def patient_last_drugs_received(patient, ref_date)
      dispensing_encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?
         AND DATE(encounter_datetime) <= DATE(?) AND program_id = ?',
        'DISPENSING', patient.patient_id, ref_date, program('HIV Program').id
      ).order(encounter_datetime: :desc).first

      return [] unless dispensing_encounter

      # HACK: Group orders in a map first to eliminate duplicates which can
      # be created when a drug is scanned twice.
      (dispensing_encounter.observations.each_with_object({}) do |obs, drug_map|
        next unless obs.value_drug || drug_map.key?(obs.value_drug)

        order = obs.order
        next unless order&.drug_order&.quantity

        drug_map[obs.value_drug] = order.drug_order if order.drug_order.drug.arv?
      end).values
    end

    # Returns patient's ART start date at current facility
    def find_patient_date_enrolled(patient)
      order = Order.joins(:encounter, :drug_order)\
                   .where(encounter: { patient: },
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

    def find_patient_recent_weight(patient_id, as_of = nil)
      as_of ||= Date.today

      vitals_encounter = Encounter.joins(:type)
                                  .merge(EncounterType.where(name: 'VITALS'))
                                  .where(program: @program, patient_id:)
                                  .where('encounter_datetime < DATE(?) + INTERVAL 1 DAY', as_of)

      Observation.joins(:encounter)
                 .merge(vitals_encounter)
                 .where(concept: ConceptName.where(name: 'Weight (kg)').select(:concept_id))
                 .where(person_id: patient_id)
                 .where('obs_datetime < DATE(?) + INTERVAL 1 DAY', as_of)
                 .first
    end

    def current_arv_code
      location_id = User.current.location_id
      global_property("site_prefix_#{location_id}")&.property_value
    end

    def arv_identifier_type
      PatientIdentifierType.find_by_name("ARV Number")
    end

    # Returns the start and end dates of the quarter for the given date.
    #
    # @param date [Date] the date to find the quarter for
    # @return [Array<Date>] the start and end dates of the quarter
    def quarter_dates(date)
      [date.beginning_of_quarter.to_date, date.end_of_quarter.to_date]
    end

    # Finds the last ARV identifier issued in the previous quarter.
    #
    # The identifier is stripped of the site prefix and the "ARV-" prefix,
    # and returned as an integer.
    #
    # @param date [Date] date to find the last ARV identifier for
    # @return [Integer] the last ARV identifier issued in the previous quarter
    def last_arv_number_from_prev_quarter(date)
      date = date&.to_date || Date.today

      current_quarter_start = date.beginning_of_quarter
      prev_quarter_start, prev_quarter_end = quarter_dates(current_quarter_start - 1.month)

      id = PatientIdentifier.where(
        identifier_type: PatientIdentifierType.find_by_name('ARV Number'),
        date_created: (prev_quarter_start..prev_quarter_end)
      ).order(date_created: :desc)
       &.first
       &.identifier

      return max_arv_number if id.nil?

      id
    end

    def max_arv_number
      PatientIdentifier.where(identifier_type: arv_identifier_type).order(:date_created).last&.identifier
    end

    # Returns the next available ARV identifier for the given date,
    # which is the lowest number not yet assigned in the current quarter.
    #
    # @param date [Date] date to generate the identifier for
    # @return [Integer] the next available ARV identifier
    def next_available_id_in_current_quarter(date)
      prefix = current_arv_code

      quarter_start, quarter_end = quarter_dates(date)
      last_available = last_arv_number_from_prev_quarter(date)&.gsub("#{prefix}-ARV-", '')&.to_i

      next_available = (last_available + 1) rescue 1

      # Find all ARV identifiers issued in the current quarter,
      # greater than the last available number from the previous quarter
      ids = PatientIdentifier.where(identifier_type: arv_identifier_type)

      return next_available unless ids.any?

      # Map the ARV identifiers to their assigned numbers
      assigned_numbers = ids.map do |identifier|
        Regexp.last_match(1).to_i if identifier.identifier =~ /#{prefix}-ARV- *(\d+)/
      end.compact

      # If there are no assigned numbers, return the next available
      # number in the current quarter.
      # 
      # which is the last available number + 1
      return next_available unless assigned_numbers.any?
      # Find the lowest number not yet assigned
      # in the current quarter by subtracting the assigned numbers from the possible number range
      # and sorting the resulting array
      available_numbers_this_qtr = (next_available..possible_number_range).to_a - assigned_numbers
      # Return the lowest number
      # which is the first element of the sorted array
      available_numbers_this_qtr.sort.first
    end

    def possible_number_range
      global_property('arv_number_range')&.property_value&.to_i || 100_000
    end

    # Finds the next available ARV identifier for the given date,
    # which is the lowest number not yet assigned in the current quarter.
    #
    # @param date [Date] date to generate the identifier for
    # @return [String] the next available ARV identifier, including the site prefix
    def find_next_available_arv_number(date)
      next_available_number = next_available_id_in_current_quarter(date)
      
      "#{current_arv_code} #{next_available_number}"
    end

    # function to check if an arv number already exists
    def arv_number_already_exists(arv_number)
      identifier_type = PatientIdentifierType.find_by_name('ARV Number')
      PatientIdentifier.all.where(
        identifier: arv_number,
        identifier_type: identifier_type.id
      ).exists?
    end

    def all_patients(paginator: nil)
      # TODO: Retrieve all patients
      []
    end

    def visit_summary_label(patient, date)
      ArtService::PatientVisitLabel.new patient, date
    end

    def transfer_out_label(patient, date)
      ArtService::PatientTransferOutLabel.new patient, date
    end

    def mastercard_data(patient, date)
      ArtService::PatientMastercard.new(patient, date).data
    end

    def patient_history_label(patient, date)
      ArtService::PatientHistory.new(patient, date)
    end

    def medication_side_effects(patient, date)
      service = ArtService::PatientSideEffect.new(patient, date)
      service.side_effects
    end

    def saved_encounters(_patient, _date)
      []
    end

    private

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

    def patient_summary(patient, date)
      PatientSummary.new patient, date
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
        'person_id = ? AND concept_id = ? AND obs_datetime <= ? AND value_drug IS NOT NULL',
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