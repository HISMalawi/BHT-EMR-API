# frozen_string_literal: true

module MnhService
  class PncStatsQueries
    include ModelUtils

    LOGGER = Rails.logger

    def initialize(program_id = nil, date = nil)
      @program_id = program_id
      @date = date.respond_to?(:to_date) ? date.to_date : date
    end

    def stats_hash
      {
        babies_receiving_bcg: babies_receiving_bcg,
        total_babies_with_immunisation_recorded: total_babies_with_immunisation_recorded,
        percentage_babies_receiving_bcg: percentage_babies_receiving_bcg,
        babies_receiving_polio_0: babies_receiving_polio_0,
        percentage_babies_receiving_polio_0: percentage_babies_receiving_polio_0,
        mothers_hiv_positive: mothers_hiv_positive,
        total_postnatal_mothers: total_postnatal_mothers,
        percentage_postnatal_mothers_hiv_positive: percentage_postnatal_mothers_hiv_positive
      }
    end

    def babies_receiving_bcg
      return 0 if pnc_program_id.nil?
      @babies_receiving_bcg ||= count_babies_receiving_bcg
    end

    def total_babies_with_immunisation_recorded
      return 0 if pnc_program_id.nil?
      @total_babies_with_immunisation_recorded ||= count_total_with_immunisation_recorded
    end

    def percentage_babies_receiving_bcg
      percentage_of(babies_receiving_bcg, total_babies_with_immunisation_recorded)
    end

    def babies_receiving_polio_0
      return 0 if pnc_program_id.nil?
      @babies_receiving_polio_0 ||= count_babies_receiving_polio_0
    end

    def percentage_babies_receiving_polio_0
      percentage_of(babies_receiving_polio_0, total_babies_with_immunisation_recorded)
    end

    def mothers_hiv_positive
      return 0 if pnc_program_id.nil?
      @mothers_hiv_positive ||= count_mothers_hiv_positive
    end

    def total_postnatal_mothers
      return 0 if pnc_program_id.nil?
      @total_postnatal_mothers ||= count_total_postnatal_mothers
    end

    def percentage_postnatal_mothers_hiv_positive
      percentage_of(mothers_hiv_positive, total_postnatal_mothers)
    end

    private

    def percentage_of(count, total)
      total.to_i.zero? ? 0.0 : (count.to_f / total * 100).round(2)
    end

    def pnc_program_id
      @pnc_program_id ||= @program_id.presence || Program.where(Program.arel_table[:name].lower.eq('pnc program')).first&.id
    end

    def concept_id_for(name)
      @concept_ids_by_name ||= {}
      @concept_ids_by_name[name] ||= ConceptName.find_by(name: name)&.concept_id
    end

    def immunisation_given_concept_id
      @immunisation_given_concept_id ||= concept_id_for('Immunisation given')
    end

    def bcg_concept_id
      @bcg_concept_id ||= concept_id_for('BCG')
    end

    def polio_0_concept_id
      @polio_0_concept_id ||= concept_id_for('Polio 0')
    end

    def mother_hiv_positive_concept_id
      @mother_hiv_positive_concept_id ||= concept_id_for('Mother HIV positive')
    end

    def yes_concept_id
      @yes_concept_id ||= concept_id_for('Yes')
    end

    def pnc_obs_scope
      scope = Observation.joins(:encounter).where(
        encounter: { program_id: pnc_program_id, voided: 0 }
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

    def pnc_encounter_scope
      scope = Encounter.where(program_id: pnc_program_id, voided: 0)
      if @date.present?
        scope = scope.where(
          encounter_datetime: @date.beginning_of_day..@date.end_of_day
        )
      end
      scope
    end

    def count_babies_receiving_bcg
      return 0 if immunisation_given_concept_id.nil? || bcg_concept_id.nil?
      pnc_obs_scope
        .where(concept_id: immunisation_given_concept_id)
        .where(value_coded: bcg_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_babies_receiving_polio_0
      return 0 if immunisation_given_concept_id.nil? || polio_0_concept_id.nil?
      pnc_obs_scope
        .where(concept_id: immunisation_given_concept_id)
        .where(value_coded: polio_0_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_total_with_immunisation_recorded
      return 0 if immunisation_given_concept_id.nil?
      pnc_obs_scope
        .where(concept_id: immunisation_given_concept_id)
        .where('obs.value_coded IS NOT NULL OR (obs.value_text IS NOT NULL AND obs.value_text != ?)', '')
        .distinct
        .count(:person_id)
    end

    def count_mothers_hiv_positive
      return 0 if mother_hiv_positive_concept_id.nil? || yes_concept_id.nil?
      pnc_obs_scope
        .where(concept_id: mother_hiv_positive_concept_id)
        .where(value_coded: yes_concept_id)
        .distinct
        .count(:person_id)
    end

    def count_total_postnatal_mothers
      pnc_encounter_scope.distinct.count(:patient_id)
    end
  end
end
