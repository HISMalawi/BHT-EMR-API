# frozen_string_literal: true

module LabourService
  class DashboardStatsQueries
    include ModelUtils

    LOGGER = Rails.logger
    SKILLED_ATTENDANT_VALUE = 'Skilled health worker (Nurse midwife/community midwife assistant/medical assistant/clinical technician/medical doctor)'

    def mothers_delivered_by_skilled_attendant
      return 0 if labour_program_id.nil?
      @mothers_delivered_by_skilled_attendant ||= count_deliveries_with_skilled_attendant
    end

    def total_deliveries_with_staff_recorded
      return 0 if labour_program_id.nil?
      @total_deliveries_with_staff_recorded ||= count_total_deliveries_with_staff_recorded
    end

    def percentage_delivered_by_skilled_attendants
      percentage_of(mothers_delivered_by_skilled_attendant, total_deliveries_with_staff_recorded)
    end

    def dashboard_stats_hash
      {
        mothers_delivered_by_skilled_attendant: mothers_delivered_by_skilled_attendant,
        total_deliveries_with_staff_recorded: total_deliveries_with_staff_recorded,
        percentage_delivered_by_skilled_attendants: percentage_delivered_by_skilled_attendants
      }
    end

    private

    def labour_program_id
      @labour_program_id ||= Program.find_by(name: 'LABOUR PROGRAM')&.id
    end

    def staff_conducting_delivery_concept_id
      @staff_conducting_delivery_concept_id ||= ConceptName.find_by(name: 'Staff conducting delivery')&.concept_id
    end

    def labour_encounter_scope
      Observation.joins(:encounter).where(
        encounter: { program_id: labour_program_id, voided: 0 }
      ).where(voided: 0)
    end

    def count_deliveries_with_skilled_attendant
      return 0 if staff_conducting_delivery_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: staff_conducting_delivery_concept_id)
        .where('obs.value_text = ?', SKILLED_ATTENDANT_VALUE)
        .distinct
        .count(:person_id)
    end

    def count_total_deliveries_with_staff_recorded
      return 0 if staff_conducting_delivery_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: staff_conducting_delivery_concept_id)
        .where('obs.value_text IS NOT NULL AND obs.value_text != ?', '')
        .distinct
        .count(:person_id)
    end

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
    end

    def percentage_ratio(count, total, decimals = 4)
      total.to_i.zero? ? 0.0 : (count.to_f / total).round(decimals)
    end
  end
end
