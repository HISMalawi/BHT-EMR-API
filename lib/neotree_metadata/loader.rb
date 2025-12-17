# frozen_string_literal: true

require 'json'
require 'pathname'

module NeotreeMetadata
  class Loader
    DATA_DIR = Rails.root.join('lib', 'data').freeze
    FILE_NAMES = %w[admission.json discharge.json].freeze
    DEFAULT_LOCALE = 'en'

    def initialize(paths: nil, creator_id: nil)
      @paths = Array(paths).compact.map { |path| Pathname.new(path) }
      @creator_id = creator_id
    end

    def load!
      raise ArgumentError, 'No metadata files provided' if metadata_paths.empty?

      ActiveRecord::Base.transaction do
        metadata_paths.each do |path|
          metadata_entries(path).each { |entry| process_entry(entry) }
        end
      end

      true
    end

    private

    attr_reader :creator_id

    def metadata_paths
      return @paths if @paths.any?

      FILE_NAMES.map { |filename| DATA_DIR.join(filename) }.select(&:exist?)
    end

    def metadata_entries(path)
      JSON.parse(path.read).map do |entry|
        entry.transform_keys(&:to_s) if entry.is_a?(Hash)
      end.compact
    end

    def process_entry(entry)
      raw_key = entry['key']
      return if raw_key.blank?

      question_concept = find_or_create_question_concept(raw_key)
      option_pairs(entry).each do |value, label|
        value_concept = find_or_create_value_concept(value, label)
        create_concept_answer(question_concept, value_concept)
      end
    end

    def option_pairs(entry)
      values = normalize_values(entry)
      labels = Array(entry['labels']).map(&:to_s).map(&:strip)
      pairs = []

      max_len = [values.length, labels.length].max
      max_len.times do |index|
        value = values[index]&.to_s&.strip
        label = labels[index]&.to_s&.strip

        value = label if value.blank? && label.present?
        next if value.blank?

        pairs << [value, label.presence]
      end

      pairs
    end

    def normalize_values(entry)
      values = Array(entry['values']).map(&:to_s).map(&:strip)
      labels = Array(entry['labels']).map(&:to_s).map(&:strip)

      # Some upstream scripts encode multiple values in a single semicolon-delimited string.
      if values.length == 1 && values.first.include?(';') && labels.length > 1
        values = values.first.split(';').map(&:strip).reject(&:blank?)
      end

      # Some scripts combine multiple codes into a single token (e.g. "HCTBA") while labels remain separate.
      if values.length < labels.length
        values = expand_compound_codes(values, needed: labels.length - values.length)
      end

      values
    end

    def expand_compound_codes(values, needed:)
      expanded = values.dup
      target_length = values.length + needed.to_i

      needed.to_i.times do
        break if expanded.empty?
        break if expanded.length >= target_length

        candidate_index = expanded.each_with_index
                                  .select { |value, _index| value.match?(/\A[A-Z]{4,}\z/) }
                                  .max_by { |value, _index| value.length }
                                  &.last
        break unless candidate_index

        candidate = expanded[candidate_index]
        split_point = candidate.length / 2
        split_point = 2 if candidate.length.odd? && candidate.length >= 5
        left = candidate[0, split_point]
        right = candidate[split_point..]
        break if left.blank? || right.blank?

        expanded[candidate_index, 1] = [left, right]
      end

      expanded
    end

    def find_or_create_question_concept(key)
      concept_name = key.to_s.strip
      return unless concept_name.present?

      existing = find_concept_by_name(concept_name)
      return existing.tap { |concept| align_neotree_question_metadata(concept, concept_name) } if existing

      Concept.create!(datatype_id: coded_datatype_id,
                      class_id: question_class_id,
                      creator: resolved_creator_id,
                      date_created: Time.current,
                      retired: 0,
                      is_set: 0,
                      short_name: concept_name,
                      description: "NeoTree question #{concept_name}" ).tap do |concept|
        add_concept_name(concept, concept_name, 'FULLY_SPECIFIED')
      end
    end

    def find_or_create_value_concept(value, label)
      choice = value.to_s.strip
      return if choice.blank?

      existing = find_concept_by_name(choice)
      return existing if existing

      Concept.create!(datatype_id: na_datatype_id,
                      class_id: value_class_id,
                      creator: resolved_creator_id,
                      date_created: Time.current,
                      short_name: choice,
                      description: "Neotree answer #{choice}" ).tap do |concept|
        add_concept_name(concept, choice, 'SHORT')
        add_concept_name(concept, label, 'FULLY_SPECIFIED') if label.present? && label != choice
      end
    end

    def create_concept_answer(question, answer)
      return unless question && answer

      ConceptAnswer.find_or_create_by!(concept_id: question.concept_id,
                                       answer_concept: answer.concept_id) do |concept_answer|
        concept_answer.creator = resolved_creator_id
        concept_answer.date_created = Time.current
      end
    end

    def add_concept_name(concept, name, type)
      return unless name.present?

      ConceptName.find_or_create_by!(concept_id: concept.concept_id,
                                     name:, locale: DEFAULT_LOCALE, concept_name_type: type) do |record|
        record.creator = resolved_creator_id
        record.date_created = Time.current
      end
    end

    def find_concept_by_name(name)
      Concept.joins(:concept_names)
             .where(concept_name: { name: name.to_s.strip })
             .first
    end

    def align_neotree_question_metadata(concept, concept_name)
      return unless concept.description == "NeoTree question #{concept_name}"

      updates = {}
      updates[:datatype_id] = coded_datatype_id if concept.datatype_id != coded_datatype_id
      updates[:class_id] = question_class_id if concept.class_id != question_class_id

      concept.update!(updates) if updates.any?
    end

    def question_class_id
      question_class&.concept_class_id || raise('Missing ConceptClass for Neotree questions')
    end

    def value_class_id
      value_class&.concept_class_id || raise('Missing ConceptClass for Neotree values')
    end

    def na_datatype_id
      na_datatype&.concept_datatype_id || raise('Missing ConceptDatatype N/A')
    end

    def coded_datatype_id
      coded_datatype&.concept_datatype_id || raise('Missing ConceptDatatype Coded')
    end

    def resolved_creator_id
      return @creator_id if @creator_id.present?

      @creator_id = User.unscoped.order(:user_id).pick(:user_id) || 1
    end

    def question_class
      @question_class ||= ConceptClass.find_by(name: 'Question')
    end

    def value_class
      @value_class ||= ConceptClass.find_by(name: 'Misc')
    end

    def na_datatype
      @na_datatype ||= ConceptDatatype.find_by(name: 'N/A')
    end

    def coded_datatype
      @coded_datatype ||= ConceptDatatype.find_by(name: 'Coded')
    end
  end
end
