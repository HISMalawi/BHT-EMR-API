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
        concepts.each do |concept_data|
          find_or_create_concept!(concept_data)
        end
      end

      puts "Successfully loaded #{concepts.size} neotree concepts"
      true
    end

    def dump
      concepts
    end

    def concepts
      @concepts ||= extract_concepts_from_metadata
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

    def extract_concepts_from_metadata
      concepts_hash = {}

      metadata_paths.each do |path|
        metadata_entries(path).each do |entry|
          # Add question concept using key
          key = entry['key']
          next if key.blank?

          # Determine question concept properties
          concepts_hash[key] = {
            name: key,
            datatype: 'Coded',
            class: 'Question'
          } unless concepts_hash.key?(key)

          # Add value concepts from labels
          labels = Array(entry['labels']).map(&:to_s).map(&:strip).reject(&:blank?)
          labels.each do |label|
            next if concepts_hash.key?(label)

            concepts_hash[label] = {
              name: label,
              datatype: determine_datatype(label),
              class: 'Misc'
            }
          end
        end
      end

      concepts_hash.values
    end

    def determine_datatype(label)
      # Simple heuristics to determine datatype from label
      # You can customize this logic based on your needs
      return 'Numeric' if label.match?(/\b(weight|temperature|saturation|count|number|rate)\b/i)
      return 'Coded' if label.match?(/\b(yes|no)\b/i)

      'Text'
    end

    def find_or_create_concept!(concept_data)
      concept_name = concept_data[:name]

      existing_concept = Concept.joins(:concept_names)
                                .where(concept_name: { name: concept_name })
                                .first

      if existing_concept
        puts "Concept '#{concept_name}' already exists (concept_id: #{existing_concept.concept_id})"
        return existing_concept
      end

      datatype = ConceptDatatype.find_by(name: concept_data[:datatype])
      klass = ConceptClass.find_by(name: concept_data[:class])

      unless datatype && klass
        raise "Missing concept datatype (#{concept_data[:datatype]}) or concept class (#{concept_data[:class]})"
      end

      concept = Concept.create!(
        datatype_id: datatype.concept_datatype_id,
        class_id: klass.concept_class_id,
        creator: resolved_creator_id,
        date_created: Time.current,
        retired: 0,
        is_set: 0
      )

      ConceptName.create!(
        concept_id: concept.concept_id,
        name: concept_name,
        locale: DEFAULT_LOCALE,
        concept_name_type: 'FULLY_SPECIFIED',
        creator: resolved_creator_id,
        date_created: Time.current
      )

      # Add numeric type metadata if applicable
      if concept_data[:datatype] == 'Numeric' && concept_data[:units]
        add_numeric_metadata(concept, concept_data[:units])
      end

      puts "Created concept '#{concept_name}' (concept_id: #{concept.concept_id})"
      concept
    end

    def add_numeric_metadata(concept, units)
      # Try to create concept numeric metadata
      begin
        ConceptNumeric.create!(
          concept_id: concept.concept_id,
          hi_absolute: nil,
          hi_critical: nil,
          hi_normal: nil,
          low_absolute: nil,
          low_critical: nil,
          low_normal: nil,
          units: units,
          precise: 1
        )
      rescue StandardError => e
        puts "  Warning: Could not create numeric metadata: #{e.message}"
      end
    end

    def resolved_creator_id
      return @creator_id if @creator_id.present?

      @creator_id = User.unscoped.order(:user_id).pick(:user_id) || 1
    end
  end
end
