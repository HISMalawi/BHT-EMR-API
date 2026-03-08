# frozen_string_literal: true

module MnhService
  class LabourStatsQueries
    include ModelUtils

    LOGGER = Rails.logger
    SKILLED_ATTENDANT_VALUE = 'Skilled health worker (Nurse midwife/community midwife assistant/medical assistant/clinical technician/medical doctor)'

    OBSTETRIC_COMPLICATION_CONDITIONS = [
      'None',
      'Postpartum haemorrhage',
      'Pre-Eclampsia',
      'Eclampsia',
      'Sepsis',
      'Retained placenta',
      'Perineal tear (2nd, 3rd or 4th degree)',
      'Other'
    ].freeze

    def initialize(program_id = nil, date = nil)
      @program_id = program_id
      @date = date.respond_to?(:to_date) ? date.to_date : date
    end

    def stats_hash
      base = {
        mothers_delivered_by_skilled_attendant: mothers_delivered_by_skilled_attendant,
        total_deliveries_with_staff_recorded: total_deliveries_with_staff_recorded,
        percentage_delivered_by_skilled_attendants: percentage_delivered_by_skilled_attendants,
        clients_delivered_at_home_or_in_transit: clients_delivered_at_home_or_in_transit,
        clients_delivered_at_this_facility: clients_delivered_at_this_facility,
        total_deliveries_with_place_recorded: total_deliveries_with_place_recorded,
        percentage_delivered_at_this_facility: percentage_delivered_at_this_facility,
        total_clients_with_obstetric_complications_recorded: total_clients_with_obstetric_complications_recorded,
        caesarean_section_count: caesarean_section_count,
        total_deliveries_with_mode_recorded: total_deliveries_with_mode_recorded,
        percentage_caesarean_section: percentage_caesarean_section
      }
      counts = obstetric_complication_counts.transform_keys { |k| "obstetric_complication_#{k}_count".to_sym }
      percentages = obstetric_complication_percentages.transform_keys { |k| "obstetric_complication_#{k}_percentage".to_sym }
      base.merge(counts).merge(percentages)
    end

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

    def clients_delivered_at_this_facility
      return 0 if labour_program_id.nil?
      @clients_delivered_at_this_facility ||= count_clients_delivered_at_this_facility
    end

    def total_deliveries_with_place_recorded
      return 0 if labour_program_id.nil?
      @total_deliveries_with_place_recorded ||= count_total_deliveries_with_place_recorded
    end

    def percentage_delivered_at_this_facility
      percentage_of(clients_delivered_at_this_facility, total_deliveries_with_place_recorded)
    end

    def total_clients_with_obstetric_complications_recorded
      return 0 if labour_program_id.nil?
      @total_clients_with_obstetric_complications_recorded ||= count_total_with_obstetric_complications_recorded
    end

    def obstetric_complication_counts
      return {} if labour_program_id.nil?
      @obstetric_complication_counts ||= count_obstetric_complications_by_condition
    end

    def obstetric_complication_percentages
      total = total_clients_with_obstetric_complications_recorded
      return {} if total.zero?
      obstetric_complication_counts.transform_values { |count| percentage_of(count, total) }
    end

    def caesarean_section_count
      return 0 if labour_program_id.nil?
      @caesarean_section_count ||= count_caesarean_section
    end

    def total_deliveries_with_mode_recorded
      return 0 if labour_program_id.nil?
      @total_deliveries_with_mode_recorded ||= count_total_deliveries_with_mode_recorded
    end

    def percentage_caesarean_section
      percentage_of(caesarean_section_count, total_deliveries_with_mode_recorded)
    end

    private

    def labour_program_id
      @labour_program_id ||= @program_id.presence || Program.where(Program.arel_table[:name].lower.eq('labour program')).first&.id
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

    def this_facility_concept_id
      @this_facility_concept_id ||= concept_id_for('This facility')
    end

    def obstetric_complications_concept_id
      @obstetric_complications_concept_id ||= concept_id_for('Obstetric complications')
    end

    def mode_of_delivery_concept_id
      @mode_of_delivery_concept_id ||= concept_id_for('Mode of delivery')
    end

    def caesarean_section_concept_id
      @caesarean_section_concept_id ||= concept_id_for('Caesarean section')
    end

    def condition_key(value)
      value.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '')
    end

    def labour_encounter_scope
      scope = Observation.joins(:encounter).where(
        encounter: { program_id: labour_program_id, voided: 0 }
      ).where(voided: 0)

      if @date.present?
        scope = scope.where(
          'encounter.encounter_datetime >= ? AND encounter.encounter_datetime <= ?',
          @date.beginning_of_day,
          @date.end_of_day
        )
      end
      scope
    end

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
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

    def count_clients_delivered_at_this_facility
      return 0 if place_of_delivery_concept_id.nil? || this_facility_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: place_of_delivery_concept_id)
        .where('obs.value_coded = ?', this_facility_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_total_deliveries_with_place_recorded
      return 0 if place_of_delivery_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: place_of_delivery_concept_id)
        .where('obs.value_coded IS NOT NULL OR (obs.value_text IS NOT NULL AND obs.value_text != ?)', '')
        .distinct
        .count(:person_id)
    end

    def count_total_with_obstetric_complications_recorded
      return 0 if obstetric_complications_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: obstetric_complications_concept_id)
        .where('obs.value_coded IS NOT NULL OR (obs.value_text IS NOT NULL AND obs.value_text != ?)', '')
        .distinct
        .count(:person_id)
    end

    def count_caesarean_section
      return 0 if mode_of_delivery_concept_id.nil? || caesarean_section_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: mode_of_delivery_concept_id)
        .where('obs.value_coded = ?', caesarean_section_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_total_deliveries_with_mode_recorded
      return 0 if mode_of_delivery_concept_id.nil?
      labour_encounter_scope
        .where(concept_id: mode_of_delivery_concept_id)
        .where('obs.value_coded IS NOT NULL OR (obs.value_text IS NOT NULL AND obs.value_text != ?)', '')
        .distinct
        .count(:person_id)
    end

    def count_obstetric_complications_by_condition
      return {} if obstetric_complications_concept_id.nil?
      result = {}
      OBSTETRIC_COMPLICATION_CONDITIONS.each do |value|
        concept_id = concept_id_for(value)
        next if concept_id.nil?
        key = condition_key(value)
        result[key] = labour_encounter_scope
          .where(concept_id: obstetric_complications_concept_id)
          .where('obs.value_coded = ?', concept_id)
          .distinct
          .count(:person_id)
      end
      result
    end
  end
end
