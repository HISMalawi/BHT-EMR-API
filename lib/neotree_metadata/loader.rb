# frozen_string_literal: true

require 'json'
require 'pathname'

module NeotreeMetadata
  class Loader
    DATA_DIR = Rails.root.join('lib', 'data').freeze
    FILE_NAMES = %w[admission.json discharge.json].freeze

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
      values = Array(entry['values']).map(&:to_s)
      labels = Array(entry['labels']).map(&:to_s)
      pairs = []

      values.each_with_index do |value, index|
        next if value.blank?

        label = labels[index]&.strip
        pairs << [value.strip, label.presence]
      end

      pairs
    end

    def find_or_create_question_concept(key)
      concept_name = key.to_s.strip
      return unless concept_name.present?

      existing = Concept.joins(:concept_names)
                        .where(class_id: question_class_id)
                        .where(concept_name: { name: concept_name })
                        .first
      return existing if existing

      Concept.create!(datatype_id: na_datatype_id,
                      class_id: question_class_id,
                      creator: resolved_creator_id,
                      date_created: Time.current,
                      short_name: concept_name,
                      description: "NeoTree question #{concept_name}" ).tap do |concept|
        add_concept_name(concept, concept_name, 'FULLY_SPECIFIED')
      end
    end

    def find_or_create_value_concept(value, label)
      choice = value.to_s.strip
      return if choice.blank?

      existing = Concept.joins(:concept_names)
                        .where(class_id: value_class_id)
                        .where(concept_name: { name: choice })
                        .first
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
                                     name:, locale: 'en', concept_name_type: type) do |record|
        record.creator = resolved_creator_id
        record.date_created = Time.current
      end
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
  end
end
