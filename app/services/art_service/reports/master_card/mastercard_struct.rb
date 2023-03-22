module ARTService::Reports::MasterCard
  class MastercardStruct
    include ModelUtils
    attr_accessor :data, :patient

    HIV_PROGRAM = Program.find_by(name: "HIV PROGRAM").program_id
    LAB_TEST_RESULT = ConceptName.find_by_name("Lab test result").concept_id

    def initialize(patient)
      @patient = patient
      @data = load_patient_data
    end

    def patient_is_a_pediatric?
      patient.age_in_months < 24
    end

    def fetch
      indicators.collect { |indicator| data.merge!(indicator) }
      data
    end

    def transfer_in_date
      if patient_history.transfer_in == "Yes"
        return { transfer_in_date: initial_observation("Transfer in date")&.answer_datetime }
      end
      { transfer_in_date: "" }
    end

    def agrees_to_followup
      { agrees_to_fup: patient_history.initial_observation("Follow up agreement").present? ? "Y" : "N" || "UNKNOWN" }
    end

    def load_patient_data
      Person.connection.select_all(
        Person.joins(:names, :addresses, :patient, :relationships, :person_attributes)
          .joins(<<-SQL)
          INNER JOIN person_name guardian ON guardian.person_id = relationship.person_b
          AND guardian.voided = 0
          INNER JOIN relationship_type ON relationship_type.relationship_type_id = relationship.relationship
          AND relationship_type.retired = 0
          INNER JOIN person_attribute guardian_phone ON `guardian_phone`.`voided` = 0
          AND guardian_phone.person_id = `guardian`.`person_id`
        SQL
          .where(person_id: patient.id)
          .where(person_attribute: { person_attribute_type_id: 12 })
          .select("person.person_id,
          person.gender as sex,
          person.birthdate as birth_date,
          CONCAT(person_name.given_name, ' ', person_name.family_name) as patient_name,
          CONCAT(guardian.given_name, ' ', guardian.family_name) as guardian_name,
          relationship_type.b_is_to_a as guardian_relation,
          person_attribute.value as patient_phone,
          CONCAT(person_address.township_division, ', ', person_address.city_village, ', ', person_address.state_province) as physical_address,
          min(guardian_phone.value) as guadian_phone")
          .to_sql
      ).to_hash.first
    end

    def initial_observation(concept)
      Observation.joins(:encounter).where(
        concept: concept,
        person_id: patient.id,
        encounter: { program_id: HIV_PROGRAM },
      ).order(obs_datetime: :asc).first
    end

    def first_visit_date
      Encounter.where(
        patient_id: patient.id,
        program_id: HIV_PROGRAM,
      ).order(encounter_datetime: :asc).first.encounter_datetime.to_date
    end

    def patient_history
      ARTService::PatientHistory.new(patient, first_visit_date)
    end

    def patient_service
      PatientService.new
    end

    def patient_visit
      ARTService::PatientVisit.new(patient, first_visit_date)
    end
  end
end
