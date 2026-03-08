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

    def clients_delivered_at_home_or_in_transit
      return 0 if labour_program_id.nil?
      @clients_delivered_at_home_or_in_transit ||= count_clients_delivered_at_home_or_in_transit
    end

    def dashboard_stats_hash
      {
        mothers_delivered_by_skilled_attendant: mothers_delivered_by_skilled_attendant,
        total_deliveries_with_staff_recorded: total_deliveries_with_staff_recorded,
        percentage_delivered_by_skilled_attendants: percentage_delivered_by_skilled_attendants,
        clients_delivered_at_home_or_in_transit: clients_delivered_at_home_or_in_transit
      }
    end

    private

    def labour_program_id
      @labour_program_id ||= Program.find_by(name: 'LABOUR PROGRAM')&.id
    end

    def concept_id_for(name)
      @concept_ids_by_name ||= {}
      @concept_ids_by_name[name] ||= ConceptName.find_by(name: name)&.concept_id
    end

    def staff_conducting_delivery_concept_id
      @staff_conducting_delivery_concept_id ||= concept_id_for('Staff conducting delivery')
    end

    def place_of_delivery_concept_id
      @place_of_delivery_concept_id ||= concept_id_for('Place of delivery')
    end

    def home_concept_id
      @home_concept_id ||= concept_id_for('Home')
    end

    def in_transit_concept_id
      @in_transit_concept_id ||= concept_id_for('In transit')
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

    def count_clients_delivered_at_home_or_in_transit
      return 0 if place_of_delivery_concept_id.nil?
      return 0 if home_concept_id.nil? && in_transit_concept_id.nil?

      scope = labour_encounter_scope.where(concept_id: place_of_delivery_concept_id)
      value_ids = [home_concept_id, in_transit_concept_id].compact
      scope = scope.where('obs.value_coded IN (?)', value_ids) if value_ids.any?
      scope.distinct.count(:person_id)
    end

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
    end

    def percentage_ratio(count, total, decimals = 4)
      total.to_i.zero? ? 0.0 : (count.to_f / total).round(decimals)
    end
  end
end
