module HTSService
  class PatientsSummary
    include ModelUtils

    attr_reader :patient
    attr_reader :date

    HTC_PROGRAM = Program.find_by_name('HTC PROGRAM').id
    PREGNANCY_STATUS_CONCEPT = ConceptName.find_by_name('Pregnancy status').concept_id
    CIRCUMCISION_STATUS_CONCEPT = ConceptName.find_by_name('Circumcision status').concept_id
    HIS_OUTCOME_CONCEPT = ConceptName.find_by_name('Antiretroviral status or outcome').concept_id
    HIV_STATUS_CONCEPT = ConceptName.find_by_name('HIV status').concept_id
    TEST_ONE_CONCEPT = ConceptName.find_by_name('Test 1').concept_id
    ART_MEDICATION_HISTORY_CONCEPT = ConceptName.find_by_name('Antiretroviral medication history').concept_id
    LAST_DATE_TAKEN_DRUGS_CONCEPT = ConceptName.find_by_name('Time since last taken medication').concept_id
    HTC_SERIAL_NUMBER_CONCEPT = ConceptName.find_by_name('HTC serial number').concept_id

    def initialize(patient, date)
      @patient = patient
      @date = date
      @hts_service = HTSService::PatientsSummary
      @service = his_patient
    end

    def full_summary
      {
        patient_id: patient.patient_id,
        test_result_date: hiv_test_result_date,
        is_pregnant: is_pregnant,
        is_circumcised: is_circumcised,
        art_outcome: art_outcome,
        ever_received_art: ever_received_art,
        last_date_taken_drugs: last_date_taken_drugs,
        htc_serial_number: htc_serial_number
      }.merge(hiv_status)
    end

    def htc_serial_number
      order_desc(
        @service.where(
          obs: {
            concept_id: HTC_SERIAL_NUMBER_CONCEPT,
          }
        )).first.value_text rescue nil
    end

    def ever_received_art
      order_desc(
        @service.where(
          obs: {
            concept_id: ART_MEDICATION_HISTORY_CONCEPT
          }
        )).first.value_coded == 1065 ? 'Yes' : 'No' rescue 'No'
    end

    def last_date_taken_drugs
      order_desc(
        @service.where(
          obs: {
            concept_id: LAST_DATE_TAKEN_DRUGS_CONCEPT
          }
        )
      ).first.obs_datetime.to_date rescue nil
    end

    def hiv_test_result_date
      order_desc(
        @service.where(
          obs: {
            concept_id: TEST_ONE_CONCEPT,
          }
        )).first.obs_datetime.to_date rescue nil
    end

    def hiv_status
      status = order_desc(
        @service.where(
          obs: {
            concept_id: HIV_STATUS_CONCEPT,
          }
        )).pluck('concept_name.name, obs.obs_datetime').first
      return {hiv_status: status[0], hiv_status_date: status[1].to_date} rescue {}
    end

    def is_pregnant
      order_desc(
        @service.where(
          obs: {
            concept_id: PREGNANCY_STATUS_CONCEPT,
          }
        )).pluck('concept_name.name').first rescue nil
    end

    def is_circumcised
      order_desc(
        @service.where(
          obs: {
            concept_id: CIRCUMCISION_STATUS_CONCEPT,
          }
        )).pluck('concept_name.name').first rescue nil
    end

    def art_outcome
      status = order_desc(
        @service.where(
          obs: {
            concept_id: HIS_OUTCOME_CONCEPT,
          }
        )).pluck('concept_name.name').first rescue nil
    end

    private

    def order_desc query
      query.order(obs_datetime: :DESC)
    end

    def his_patient
       Observation.joins(encounter: :program)
            .joins(<<-SQL)
              LEFT JOIN concept_name ON concept_name.concept_id = obs.value_coded
             SQL
            .where(
              obs: {person_id: patient.id},
              program: { program_id: HTC_PROGRAM }
            )
    end
  end
end