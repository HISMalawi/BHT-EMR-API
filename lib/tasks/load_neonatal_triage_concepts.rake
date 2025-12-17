# frozen_string_literal: true

namespace :neonatal do
  desc 'Load Neonatal Triage concepts'
  task load_triage_concepts: :environment do
    loader = NeonatalTriage::ConceptLoader.new
    loader.load!
  end
end

module NeonatalTriage
  class ConceptLoader
    CONCEPTS = [
      { name: 'Baby crying', datatype: 'Coded', class: 'Question' },
      { name: 'Baby breathing status', datatype: 'Text', class: 'Finding' },
      { name: 'Oxygen saturation in oxygen', datatype: 'Numeric', class: 'Misc', units: '%' },
      { name: 'Can measure oxygen saturation', datatype: 'Coded', class: 'Question' },
      { name: 'Oxygen available at facility', datatype: 'Coded', class: 'Question' },
      { name: 'Central cyanosis', datatype: 'Coded', class: 'Question' },
      { name: 'Clinical observations', datatype: 'Text', class: 'Finding' },
      { name: 'Danger signs present', datatype: 'Text', class: 'Finding' },
      { name: 'Can measure temperature', datatype: 'Coded', class: 'Question' },
      { name: 'Blood sugar unit', datatype: 'Text', class: 'Misc' },
      { name: 'First name', datatype: 'Text', class: 'Misc' },
      { name: 'Last name', datatype: 'Text', class: 'Misc' },
      { name: 'Referral required', datatype: 'Text', class: 'Question' },
      { name: 'Referral notes', datatype: 'Text', class: 'Misc' },
      { name: 'Referral facility', datatype: 'Text', class: 'Misc' },
      { name: 'Transport method', datatype: 'Text', class: 'Misc' }
    ].freeze

    def load!
      ActiveRecord::Base.transaction do
        CONCEPTS.each do |concept_data|
          find_or_create_concept!(concept_data)
        end
      end
      puts "Successfully loaded #{CONCEPTS.size} neonatal triage concepts"
    end

    private

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
        creator: creator_id,
        date_created: Time.now,
        retired: 0,
        is_set: 0
      )

      ConceptName.create!(
        concept_id: concept.concept_id,
        name: concept_name,
        locale: 'en',
        concept_name_type: 'FULLY_SPECIFIED',
        creator: creator_id,
        date_created: Time.now
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

    def creator_id
      @creator_id ||= User.unscoped.order(:user_id).pick(:user_id) || 1
    end
  end
end
