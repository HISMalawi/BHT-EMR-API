# frozen_string_literal: true

class TbService::TbQueries::PotentialStatesQuery
  include ModelUtils

  STATES = {
    TB_RX: 92
  }.freeze

  DAYS_TO_DEFAULT = 56

  def initialize
    @program = program('TB Program')
  end

  def defaulted
    treatment = encounter_type('Treatment').encounter_type_id

    in_rx = in_treatment
    return [] if in_rx.empty?

    rx_str = in_rx.map(&:patient_id).join(',')

    defaulters = ActiveRecord::Base.connection.select_all(
                  <<~SQL
                    SELECT patient.patient_id, MAX(encounter_datetime) AS 'last_visit'
                    FROM patient JOIN encounter USING(patient_id)
                    WHERE program_id = #{@program.program_id} AND encounter_type = #{treatment}
                    AND encounter.voided = 0 AND patient.voided = 0 AND patient.patient_id in (#{rx_str})
                    GROUP BY patient.patient_id
                    HAVING TIMESTAMPDIFF(DAY, last_visit, now()) > #{DAYS_TO_DEFAULT}
                  SQL
                )

    return [] if defaulters.empty?

    Patient.where(patient_id: defaulters.map { |patient| patient['patient_id'] })
  end

  private

  def in_treatment
    Patient.joins(patient_programs: :patient_states)\
           .where(patient_program: { program_id: @program })\
           .where(patient_state: { end_date: nil, state: STATES[:TB_RX] })
  end
end
