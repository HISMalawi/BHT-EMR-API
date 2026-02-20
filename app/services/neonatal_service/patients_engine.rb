
module NeonatalService
  class PatientsEngine
    include ModelUtils

    attr_reader :program

    LOGGER = Rails.logger

    def initialize(program:)
      @program = program
    end

    def patient(patient_id, date = Date.today)
      patient = Patient.find(patient_id)
      patient_summary(patient, date).full_summary
    end

    def saved_encounters(patient, _date = nil)
      patient_id = patient.patient_id || patient.id

      Encounter.joins(:type)
               .where(program_id: @program.program_id, patient_id: patient_id, voided: 0)
               .order(:encounter_datetime)
               .pluck('encounter_type.name')
               .uniq
    end

    def enrolled_patients(filters = {})
      relation = PatientProgram.joins(:patient)
                               .where(program_id: @program.program_id)

      relation = relation.where('date_enrolled <= ?', filters[:date]) if filters[:date]
      relation = relation.where('date_completed IS NULL OR date_completed >= ?', filters[:date] || Date.today)

      paginate(relation, filters[:page], filters[:per_page])
    end

    def search_patients(search_params = {})
      relation = PatientProgram.joins(:patient)
                               .where(program_id: @program.program_id)

      if search_params[:name].present?
        name_query = "%#{search_params[:name]}%"
        relation = relation.joins('INNER JOIN person_name ON person_name.person_id = patient.patient_id')
                           .where('person_name.given_name LIKE ? OR person_name.family_name LIKE ?',
                                  name_query, name_query)
      end

      if search_params[:identifier].present?
        relation = relation.joins('INNER JOIN patient_identifier ON patient_identifier.patient_id = patient.patient_id')
                           .where('patient_identifier.identifier LIKE ?', "%#{search_params[:identifier]}%")
      end

      if search_params[:date_enrolled].present?
        relation = relation.where('DATE(date_enrolled) = ?', search_params[:date_enrolled].to_date)
      end

      relation.distinct
    end

    def patients_visited_on(date)
      Patient.joins(:encounters)
             .where('encounter.program_id = ?', @program.program_id)
             .where('DATE(encounter.encounter_datetime) = ?', date.to_date)
             .distinct
    end

    def patients_with_appointments_on(date)
      appointment_type = encounter_type('APPOINTMENT')
      return [] unless appointment_type

      appointments = Observation.joins(:encounter, :concept)
                                .where('encounter.program_id = ?', @program.program_id)
                                .where('encounter.encounter_type = ?', appointment_type.encounter_type_id)
                                .where('concept.concept_id = ?', concept('Appointment date')&.concept_id)
                                .where('DATE(obs.value_datetime) = ?', date.to_date)
                                .select('obs.*, encounter.*')

      appointments.map do |appointment|
        {
          patient_id: appointment.encounter.patient_id,
          patient: Patient.find(appointment.encounter.patient_id),
          appointment_date: appointment.value_datetime,
          encounter_id: appointment.encounter_id
        }
      end
    end

    STAT_STATUSES = {
      enrolled: 'In patient',
      admitted: 'Admitted',
      discharged: 'Discharged',
      critical: 'Critical',
      triage_only: 'Triage Only - Pending Registration'
    }.freeze

    CRITICAL_DIAGNOSIS_NAMES = [
      'Suspected neonatal sepsis',
      'Possible Meconium Aspiration',
      'Convulsions',
      'Hypoglycaemia (symptomatic)',
      'Extremely Low Birth Weight (<1000g)',
      'Severe Hypothermia',
      'Extremely Premature (<28 weeks)',
      'Hypoxic Ischaemic Encephalopathy',
      'Prematurity with Respiratory Distress',
      'Term baby with Respiratory Distress',
      'NSep',
      'MA',
      'Conv',
      'HypogSy',
      'ExLBW',
      'SHypo',
      'ExPrem',
      'HIE',
      'PremRD',
      'TermRD',
      'RiHypog'
    ].freeze

    def statistics(date = Date.today)
      {
        enrolled: build_statistic_from_programs(patients_enrolled_on(date), date, STAT_STATUSES[:enrolled]),
        admitted: build_statistic(patients_admitted_on(date), date, STAT_STATUSES[:admitted]),
        discharged: build_statistic_from_programs(patients_discharged_on(date), date, STAT_STATUSES[:discharged]),
        critical: build_statistic(critical_patients(date), date, STAT_STATUSES[:critical]),
        critical_attention: build_statistic(critical_attention_patients(date), date, STAT_STATUSES[:critical]),
        triage_only: build_statistic(triage_only_patients(date), date, STAT_STATUSES[:triage_only]),
        recent_neonates: get_recent_neonates(date)
      }
    end

    def statistics_for_range(start_date, end_date)
      start_date = start_date.to_date
      end_date = end_date.to_date

      enrolled = aggregate_patients_over_range(start_date, end_date) { |date| patients_enrolled_on(date).map(&:patient).compact }
      admitted = aggregate_patients_over_range(start_date, end_date) { |date| patients_admitted_on(date) }
      discharged = aggregate_patients_over_range(start_date, end_date) { |date| patients_discharged_on(date).map(&:patient).compact }
      critical = aggregate_patients_over_range(start_date, end_date) { |date| critical_patients(date) }
      critical_attention = aggregate_patients_over_range(start_date, end_date) { |date| critical_attention_patients(date) }
      triage_only = aggregate_patients_over_range(start_date, end_date) { |date| triage_only_patients(date) }

      {
        enrolled: build_statistic(enrolled, end_date, STAT_STATUSES[:enrolled]),
        admitted: build_statistic(admitted, end_date, STAT_STATUSES[:admitted]),
        discharged: build_statistic(discharged, end_date, STAT_STATUSES[:discharged]),
        critical: build_statistic(critical, end_date, STAT_STATUSES[:critical]),
        critical_attention: build_statistic(critical_attention, end_date, STAT_STATUSES[:critical]),
        triage_only: build_statistic(triage_only, end_date, STAT_STATUSES[:triage_only]),
        recent_neonates: get_recent_neonates(end_date)
      }
    end


    def get_recent_neonates(date = Date.today, limit = 10)
      start_date = date.to_date - 7.days
      end_date = date.to_date

      recent_patients = Encounter
        .select('patient.*, person.birthdate, MAX(encounter.encounter_datetime) as last_encounter_time')
        .joins(:patient)
        .joins('INNER JOIN person ON person.person_id = patient.patient_id')
        .where('encounter.program_id = ?', @program.program_id)
        .where('encounter.voided = ?', 0)
        .where('DATE(encounter.encounter_datetime) BETWEEN ? AND ?', start_date, end_date)
        .where('person.birthdate IS NOT NULL')
        .where('DATEDIFF(?, person.birthdate) <= ?', date.to_date, 28)
        .group('patient.patient_id')
        .order('last_encounter_time DESC')
        .limit(limit)
        .map(&:patient)
        .compact

      recent_patients.map do |patient|
        status = determine_patient_status(patient, date)
        format_neonate(patient, status, date)
      end
    end


    def determine_patient_status(patient, date)
      program = PatientProgram.find_by(
        patient_id: patient.patient_id,
        program_id: @program.program_id
      )

      return STAT_STATUSES[:discharged] if program && program.date_completed && program.date_completed <= date

      triage_concept = concept('Triage priority')
      emergency_value = concept('Emergency')

      if triage_concept && emergency_value
        has_emergency = Observation
          .joins(:encounter)
          .where(encounter: { patient_id: patient.patient_id, program_id: @program.program_id, voided: 0 })
          .where(voided: 0, concept_id: triage_concept.concept_id, value_coded: emergency_value.concept_id)
          .where('DATE(obs_datetime) >= ?', date - 1.day)
          .exists?

        return STAT_STATUSES[:critical] if has_emergency
      end

      admission_encounter_names = [
        'NEONATAL SIGNS & SYMPTOMS',
        'NEONATAL REVIEW OF SYSTEMS',
        'PHYSICAL EXAMINATION BABY',
        'NEONATAL GENERAL EXAMINATION',
        'VITALS',
        'NEONATAL VITALS',
        'NEONATAL SYSTEMIC EXAMINATION'
      ]

      encounter_types = EncounterType.where(name: admission_encounter_names)
      if encounter_types.any?
        has_admission_encounter_today = Encounter
          .where(patient_id: patient.patient_id, program_id: @program.program_id)
          .where(encounter_type: encounter_types.pluck(:encounter_type_id), voided: 0)
          .where('DATE(encounter_datetime) = ?', date)
          .exists?

        return STAT_STATUSES[:admitted] if has_admission_encounter_today
      end

      STAT_STATUSES[:enrolled]
    end


    def total_enrolled_patients(date = Date.today)
      PatientProgram.where(program_id: @program.program_id)
                    .where('date_enrolled <= ?', date)
                    .count
    end


    def patients_enrolled_on(date)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where('DATE(date_enrolled) = ?', date.to_date)
                    .includes(patient: { person: :names })
    end


    def patients_discharged_on(date)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where.not(date_completed: nil)
                    .where('DATE(date_completed) = ?', date.to_date)
                    .includes(patient: { person: :names })
    end


    def active_patients(date = Date.today)
      PatientProgram.joins(:patient)
                    .where(program_id: @program.program_id)
                    .where('date_enrolled <= ?', date)
                    .where('date_completed IS NULL OR date_completed >= ?', date)
    end

    def next_appointment(patient)
      appointment_type = encounter_type('APPOINTMENT')
      return nil unless appointment_type

      appointment_obs = Observation.joins(:encounter)
                                   .where('encounter.patient_id = ?', patient.patient_id)
                                   .where('encounter.program_id = ?', @program.program_id)
                                   .where('encounter.encounter_type = ?', appointment_type.encounter_type_id)
                                   .where('encounter.concept_id = ?', concept('Appointment date')&.concept_id)
                                   .where('obs.value_datetime >= ?', Date.today)
                                   .order('obs.value_datetime ASC')
                                   .first

      return nil unless appointment_obs

      {
        appointment_date: appointment_obs.value_datetime,
        encounter_id: appointment_obs.encounter_id,
        days_until_appointment: (appointment_obs.value_datetime.to_date - Date.today).to_i
      }
    end

    def visit_history(patient, limit = 10)
      Encounter.where(patient_id: patient.patient_id, program_id: @program.program_id)
               .order(encounter_datetime: :desc)
               .limit(limit)
               .group_by { |e| e.encounter_datetime.to_date }
               .map do |date, encounters|
        {
          date: date,
          encounters: encounters.map { |e| { type: e.type.name, id: e.encounter_id } }
        }
      end
    end


    def patient_labels(patient, date = Date.today)
      labels = []

      unless enrolled?(patient)
        labels << 'NOT ENROLLED'
        return labels
      end

      age_in_days = (date - patient.birthdate).to_i
      if age_in_days > 28
        labels << 'BEYOND NEONATAL PERIOD'
      elsif age_in_days <= 7
        labels << 'EARLY NEONATAL'
      else
        labels << 'LATE NEONATAL'
      end

      next_appt = next_appointment(patient)
      if next_appt
        if next_appt[:days_until_appointment].zero?
          labels << 'APPOINTMENT TODAY'
        elsif next_appt[:days_until_appointment] < 0
          labels << 'MISSED APPOINTMENT'
        elsif next_appt[:days_until_appointment] <= 7
          labels << "APPOINTMENT IN #{next_appt[:days_until_appointment]} DAYS"
        end
      end

      labels << 'VISITED TODAY' if visited_today?(patient, date)
      labels
    end

    private


    def patient_summary(patient, date)
      NeonatalService::PatientSummary.new(patient, date, @program)
    end

    def patients_admitted_on(date)
      admission_encounter_names = [
        'NEONATAL SIGNS & SYMPTOMS',
        'NEONATAL REVIEW OF SYSTEMS',
        'PHYSICAL EXAMINATION BABY',
        'NEONATAL GENERAL EXAMINATION',
        'VITALS',
        'NEONATAL VITALS',
        'NEONATAL SYSTEMIC EXAMINATION'
      ]

      encounter_types = EncounterType.where(name: admission_encounter_names)
      return [] if encounter_types.empty?

      Encounter.where(program_id: @program.program_id, encounter_type: encounter_types.pluck(:encounter_type_id), voided: 0)
               .where('DATE(encounter_datetime) = ?', date.to_date)
               .includes(:patient)
               .map(&:patient)
               .compact
               .uniq { |patient| patient.patient_id }
    end

    def critical_patients(date)
      triage_concept = concept('Triage priority')
      emergency_value = concept('Emergency')
      return [] unless triage_concept && emergency_value

      Observation.joins(:encounter)
                 .where(encounter: { program_id: @program.program_id, voided: 0 })
                 .where(voided: 0)
                 .where(concept_id: triage_concept.concept_id, value_coded: emergency_value.concept_id)
                 .where('DATE(obs_datetime) = ?', date.to_date)
                 .includes(encounter: :patient)
                 .map { |obs| obs.encounter.patient }
                 .compact
                 .uniq { |patient| patient.patient_id }
    end

    def critical_attention_patients(date)
      primary_diagnosis = concept('Primary diagnosis')
      secondary_diagnosis = concept('Secondary diagnosis')

      diagnosis_ids = CRITICAL_DIAGNOSIS_NAMES.map { |name| concept(name)&.concept_id }.compact
      return [] if diagnosis_ids.empty? || (!primary_diagnosis && !secondary_diagnosis)

      parent_concept_ids = []
      parent_concept_ids << primary_diagnosis.concept_id if primary_diagnosis
      parent_concept_ids << secondary_diagnosis.concept_id if secondary_diagnosis

      parent_obs_ids = Observation.joins(:encounter)
                                  .where(encounter: { program_id: @program.program_id, voided: 0 })
                                  .where(voided: 0)
                                  .where(concept_id: parent_concept_ids)
                                  .where('DATE(obs_datetime) = ?', date.to_date)
                                  .pluck(:obs_id)

      return [] if parent_obs_ids.empty?

      Observation.joins(:encounter)
                 .where(encounter: { program_id: @program.program_id, voided: 0 })
                 .where(voided: 0)
                 .where(obs_group_id: parent_obs_ids)
                 .where(concept_id: diagnosis_ids)
                 .where('DATE(obs_datetime) = ?', date.to_date)
                 .includes(encounter: :patient)
                 .map { |obs| obs.encounter.patient }
                 .compact
                 .uniq { |patient| patient.patient_id }
    end

    def aggregate_patients_over_range(start_date, end_date)
      patients = []
      (start_date..end_date).each do |date|
        patients.concat(Array(yield(date)))
      end
      patients.compact.uniq { |patient| patient.patient_id }
    end

    def triage_only_patients(date)
      triage_encounter_type = EncounterType.find_by(name: 'NEONATAL TRIAGE')
      return [] unless triage_encounter_type

      patients_with_triage = Encounter
        .where(program_id: @program.program_id, encounter_type: triage_encounter_type.encounter_type_id, voided: 0)
        .where('DATE(encounter_datetime) = ?', date.to_date)
        .includes(:patient)
        .map(&:patient)
        .compact
        .uniq { |patient| patient.patient_id }

      patients_with_triage.select do |patient|
        person = patient.person
        next false unless person


        other_encounter_types = [
          'NEONATAL ENROLLMENT',
          'NEONATAL SIGNS & SYMPTOMS',
          'NEONATAL REVIEW OF SYSTEMS',
          'PHYSICAL EXAMINATION BABY',
          'NEONATAL GENERAL EXAMINATION',
          'NEONATAL VITALS',
          'NEONATAL SYSTEMIC EXAMINATION'
        ]

        encounter_types = EncounterType.where(name: other_encounter_types)
        has_other_encounters = Encounter
          .where(patient_id: patient.patient_id, program_id: @program.program_id, voided: 0)
          .where(encounter_type: encounter_types.pluck(:encounter_type_id))
          .exists?

        !has_other_encounters
      end
    end

    def build_statistic_from_programs(program_relation, date, status)
      patients = program_relation.map(&:patient).compact
      build_statistic(patients, date, status)
    end

    def build_statistic(patients, date, status)
      unique_patients = patients.compact.uniq { |patient| patient.patient_id }
      {
        count: unique_patients.length,
        neonates: unique_patients.map { |patient| format_neonate(patient, status, date) }
      }
    end

    def format_neonate(patient, status, date)
      person = patient.person
      {
        id: patient.patient_id,
        name: formatted_name(person),
        mrn: patient_identifier_value(patient),
        age: format_age(person, date),
        weight: format_weight(patient, date),
        status: status
      }
    end

    def formatted_name(person)
      return 'Unknown Neonate' unless person

      name = person.names.first
      parts = [name&.given_name, name&.middle_name, name&.family_name].compact.map(&:strip).reject(&:blank?)
      value = parts.join(' ')
      value.present? ? value : 'Unknown Neonate'
    end

    def patient_identifier_value(patient)
      identifier = patient.national_id
      return identifier if identifier.present?

      patient.patient_identifiers.order(:date_created).last&.identifier || 'N/A'
    end

    def format_age(person, date)
      return 'Unknown' unless person&.birthdate

      reference_date = date.to_date
      age_days = (reference_date - person.birthdate).to_i
      return 'Today' if age_days.zero?
      return "#{age_days} day#{'s' unless age_days == 1} old" if age_days.positive? && age_days < 30

      weeks = (age_days / 7.0).floor
      if weeks.positive? && weeks < 4
        "#{weeks} week#{'s' unless weeks == 1} old"
      else
        "#{age_days} day#{'s' unless age_days == 1} old"
      end
    end

    def format_weight(patient, date)
      value = patient.weight(today: date)
      return nil unless value

      format('%.2f Kg', value)
    end

    def enrolled?(patient)
      PatientProgram.where(
        patient_id: patient.patient_id,
        program_id: @program.program_id
      ).where('date_completed IS NULL OR date_completed >= ?', Date.today)
       .exists?
    end

    def visited_today?(patient, date)
      Encounter.where(patient_id: patient.patient_id, program_id: @program.program_id)
               .where('DATE(encounter_datetime) = ?', date.to_date)
               .exists?
    end

    def paginate(relation, page = nil, per_page = nil)
      return relation unless page && per_page

      offset = (page.to_i - 1) * per_page.to_i
      relation.offset(offset).limit(per_page.to_i)
    end
  end
end
