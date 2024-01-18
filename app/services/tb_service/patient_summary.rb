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
      @date = date
    end

    def full_summary
      drug_start_date, drug_duration = drug_period
      {
        patient_id: patient.patient_id,
        npid: identifier(NPID_TYPE) || 'N/A',
        tb_number: tb_number,
        program_start_date: patient_program_start_date || 'N/A',
        current_outcome: current_outcome || 'N/A',
        current_drugs: current_drugs,
        residence: residence,
        drug_duration: drug_duration || 'N/A',
        drug_start_date: drug_start_date&.strftime('%d/%m/%Y') || 'N/A'
      }
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
      program = Program.find_by(name: 'TB PROGRAM')

      state = PatientState.joins(:patient_program)\
                          .includes(:program_workflow_state)
                          .where('start_date <= ?', date)\
                          .merge(PatientProgram.where(program: program, patient: patient))\
                          .order(start_date: :desc)\
                          .last

      state.program_workflow_state.name
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
      concept = ConceptName.find_by_name(concept_name)
      date = Observation.where(concept_id: concept.concept_id,
                               person_id: patient.patient_id)\
                        .order(obs_datetime: :desc)\
                        .first\
                        &.value_datetime
      return nil if date.blank?

      date
    end

    def tb_number
      number = TbNumberService.get_patient_tb_number(patient_id: patient.patient_id)
      return 'N/A' unless number

      number[:identifier]
    end

    def patient_program_start_date
      patient_program = PatientProgram.find_by(patient_id: patient.patient_id, program_id: program('TB PROGRAM').program_id)
      return 'N/A' unless patient_program

      patient_program.date_enrolled.to_date
    end

    private
  end
  end
