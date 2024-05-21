# frozen_string_literal: true

class TbService::TbQueries::RegisteredPatientsQuery
  include ModelUtils

  TB_PROGRAM_ID = 2 # find out while program is not visible in this scope
  TREATMENT_ENC = 25
  DISPENSATION_ENC = 54
  TREATMENT_STATE = 92
  NORMAL_TREATMENT_SPAN = 168
  TB_NUMBER_REGEX = '^[A-Za-z]+\/(TB|IPT)\/[0-9]+\/[0-9]+$'

  def initialize(relation = Patient.includes(:patient_identifiers, person: :addresses, patient_programs: :patient_states).all)
    @relation = relation.extending(Scopes)
  end

  def ref(start_date, end_date)
    tb_number = concept('TB registration number')
    @relation.joins(encounters: :observations)\
             .where(obs: { concept_id: tb_number, obs_datetime: start_date..end_date })
  end

  module Scopes
    def without_program
        where("patient.patient_id NOT IN (SELECT patient_id FROM patient_program WHERE program_id=#{TB_PROGRAM_ID} and voided = 0)")\
        .distinct
    end

    def with_duplicate_tb_number
      having('COUNT(*) > 1').group(:patient_id)
    end

    def with_unknown_outcome
      joins(:patient_programs)\
        .joins('LEFT JOIN patient_state ON patient_program.patient_program_id = patient_state.patient_program_id')\
        .where("patient_program.program_id=#{TB_PROGRAM_ID} AND patient_state.patient_state_id IS NULL")\
        .distinct
    end

    def with_dispensation_anomalies
      anomalies = ActiveRecord::Base.connection.select_all(
        <<~SQL
          SELECT DISTINCT(patient_id), GROUP_CONCAT(encounter_type) AS encounters FROM encounter
          WHERE program_id = #{TB_PROGRAM_ID} AND voided = 0 GROUP BY patient_id, DATE(encounter_datetime)
          HAVING encounters LIKE '%#{TREATMENT_ENC}%' AND encounters NOT LIKE '%#{DISPENSATION_ENC}%'
        SQL
      )

      return [] unless anomalies

      ids = anomalies.map { |anomaly| anomaly['patient_id'] }
      where(patient_id: ids).distinct
    end

    def defaulted; end

    def in_treatment_but_completed
      joins(patient_programs: :patient_states)\
        .where(patient_program: { program_id: TB_PROGRAM_ID },
               patient_state: { state: TREATMENT_STATE, end_date: nil })\
        .where("TIMESTAMPDIFF(DAY, patient_state.start_date, NOW()) >= #{NORMAL_TREATMENT_SPAN}")\
        .distinct
    end
  end
end
