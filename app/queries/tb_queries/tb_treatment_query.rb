class TBQueries::TbTreatmentQuery
  STATES = {
    :TB_RX => 92,
    :ART_RX => 7
  }.freeze
  include ModelUtils

  def initialize (relation = PatientState.includes(:patient_program))
    @relation = relation
    @program = program('TB Program')
  end

  def started_after_art (start_date, end_date)
    in_tb_rx = in_tb_treatment(start_date, end_date)
    return [] if in_tb_rx.empty?

    ids = in_tb_rx.map { |state| state&.patient_program&.patient_id }

    also_in_art_rx = tb_rx_in_art_rx(patient_ids: ids)
    return [] if also_in_art_rx.empty?

    started_after = also_in_art_rx.select do |in_art|
      in_tb_rx.select do |in_tb|
        (in_art.patient_program.patient_id == in_tb.patient_program.patient_id) && (in_art.date_created < in_tb.date_created)
      end.size > 0
    end

    started_after.map { |state| state&.patient_program&.patient_id }
  end

  def started_before_art (start_date, end_date)
    in_tb_rx = in_tb_treatment(start_date, end_date)
    return [] if in_tb_rx.empty?

    ids = in_tb_rx.map { |state| state&.patient_program&.patient_id }

    also_in_art_rx = tb_rx_in_art_rx(patient_ids: ids)
    return [] if also_in_art_rx.empty?

    started_before = in_tb_rx.select do |in_tb|
      answer = also_in_art_rx.select do |in_art|
        (in_tb.patient_program.patient_id == in_art.patient_program.patient_id) && (in_tb.date_created < in_art.date_created)
      end.size > 0
    end

    started_before.map { |state| state&.patient_program&.patient_id }
  end

  private
  def in_tb_treatment (start_date, end_date)
    states = @relation.where(state: STATES[:TB_RX], end_date: nil, date_created: start_date..end_date)
  end

  def tb_rx_in_art_rx (patient_ids:)
    @relation.where(:patient_state => { state: STATES[:ART_RX],
                                        end_date: nil },
                    :patient_program => { patient_id: patient_ids })
  end
end