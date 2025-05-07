# frozen_string_literal: true

module TbService
  # Provides various summary statistics for an TB patient
  class PatientSummary
    NPID_TYPE = 'National id'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    attr_reader :patient
    attr_reader :date

    def initialize(patient, date)
      @patient = patient
      @program = get_program
      @date = date
    end

    def full_summary
      drug_start_date, drug_duration = drug_period
      {
        tb_positive: tb_status,
        patient_id: patient.patient_id,
        npid: identifier(NPID_TYPE) || 'N/A',
        tb_number: tb_number,
        malawi_national_id: mw_national_id,
        program_start_date: patient_program_start_date || 'N/A',
        current_outcome: current_outcome[:name] || 'N/A',
        current_outcome_date: current_outcome[:date] || 'N/A',
        current_drugs: current_drugs,
        residence: residence,
        drug_duration: drug_duration || 'N/A',
        drug_start_date: drug_start_date&.strftime('%d/%m/%Y') || 'N/A',
        last_treatment_outcome_date: last_outcome_date,
        hiv: hiv?,
        eptb: eptb?,
        age: age,
        patient: patient
      }
    end

    def mw_national_id
      national_identifier = TbNumberService.mw_national_identifier(patient.patient_id)
      national_identifier.identifier if not national_identifier.nil?
    end

    def tb_status
      positive = concept('Positive').concept_id
        obs = Observation.where(concept: concept('TB status'), person_id: @patient)
                   .where('obs_datetime > ? AND DATE(obs_datetime) <= DATE(?)', last_outcome_date, @date)
                   .first
      return obs.value_coded == positive if obs.present?
      nil
    end

    def last_outcome_date
      service = PatientService.new
      service.patient_last_outcome_date @patient.patient_id, @program.program_id, @date
    end

    def identifier(identifier_type_name)
      identifier_type = PatientIdentifierType.find_by_name(identifier_type_name)
      PatientIdentifier.where(
        identifier_type: identifier_type.patient_identifier_type_id,
        patient_id: patient.patient_id
      ).first&.identifier
    end

    def residence
      address = patient.person.addresses[0]
      return 'N/A' unless address

      district = address.state_province || 'Unknown District'
      village = address.city_village || 'Unknown Village'
      "#{district}, #{village}"
    end

    def current_drugs
      prescribe_drugs = Observation.where(person_id: patient.patient_id,
                                          concept: concept('Prescribe drugs'),
                                          value_coded: concept('Yes').concept_id)\
                                   .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                   .order(obs_datetime: :desc)
                                   .first

      return {} unless prescribe_drugs

      tb_extras_concepts = [concept('Rifampicin isoniazid and pyrazinamide'), concept('Ethambutol'), concept('Rifampicin and isoniazid'), concept('Rifampicin Isoniazid Pyrazinamide Ethambutol')] # add TB concepts

      orders = Observation.where(concept: concept('Medication orders'),
                                 person: patient.person)
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))

      orders.each_with_object({}) do |order, dosages|
        next unless order.value_coded # Raise a warning here

        drug_concept = Concept.find_by(concept_id: order.value_coded)
        unless drug_concept
          Rails.logger.warn "Couldn't find drug concept using value_coded ##{order.value_coded} of order ##{order.order_id}"
          next
        end

        next unless tb_extras_concepts.include?(drug_concept)

        drugs = Drug.where(concept: drug_concept)

        ingredients = NtpRegimen.where(drug: drugs)\
                                .where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                                  AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                       weight: patient.weight.to_f.round(1))
        ingredients

        ingredients.each do |ingredient|
          drug = Drug.find_by(drug_id: ingredient.drug_id)
          dosages['drug_name'] = drug.name
        end
      end
    end

    def current_outcome
      patient_state_service = PatientStateService.new
      begin
        state = patient_state_service.find_patient_state(@program, @patient, @date)
        { name: state.name, date: state.start_date }
      rescue => exception
        { name: 'N/A', date: 'N/A'}
      end
    end

    def drug_period
      start_date = (recent_value_datetime('TB drug start date')\
                    || recent_value_datetime('Drug start date'))

      return [nil, nil] unless start_date

      duration = ((Time.now - start_date) / SECONDS_IN_MONTH).to_i # Round off to preceeding integer
      [start_date, duration] # Reformat date
    end

    # Returns the most recent value_datetime for patient's observations of the
    # given concept
    def recent_value_datetime(concept_name)
      concpt = ConceptName.find_by_name(concept_name)
      date = Observation.where(concept_id: concpt.concept_id,
                               person_id: patient.patient_id)\
                        .order(obs_datetime: :desc)\
                        .first\
                        &.value_datetime
      return nil if date.blank?

      date
    end

    def tb_number
      number = TbNumberService.get_current_patient_identifier(patient_id: patient.patient_id)
      return 'N/A' unless number
      number[:identifier]
    end

    def patient_program_start_date
      patient_program = PatientProgram.find_by(patient_id: @patient, program_id: @program)
      return 'N/A' unless patient_program

      patient_program.date_enrolled.to_date
    end

    private


    def get_program
      ipt? ? program('IPT Program') : program('TB Program')
    end

    def ipt?
      PatientProgram.joins(:patient_states)\
                    .where(patient_program: { patient_id: @patient,
                                              program_id: program('IPT Program') },
                           patient_state: { end_date: nil })\
                    .exists?
    end

    def hiv?
      Observation.where(person_id: @patient.patient_id,
                        concept: concept('HIV status'),
                        value_coded: concept('Positive').concept_id)\
                      .where('DATE(obs_datetime) <= DATE(?)', @date)
                      .order(obs_datetime: :desc)
                      .first
                      .present?
    end

    def age
      person = Person.find_by(person_id: @patient.patient_id)
      ((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor
    end

    def eptb?
      obs = Observation.where(person_id: @patient.patient_id,
                              concept: concept('Type of tuberculosis'))
                        .where('DATE(obs_datetime) <= DATE(?)', @date)
                        .order(obs_datetime: :desc)
                        .first
      obs.present? ? obs.value_coded == concept('Extrapulmonary tuberculosis (EPTB)').concept_id : false
    end
  end
  end
