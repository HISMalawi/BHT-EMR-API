# frozen_string_literal: true

namespace :neonatal do
  desc 'Load Neonatal program metadata (concept + program)'
  task load_program: :environment do
    loader = NeonatalProgram::Loader.new
    loader.load!
  end
end

module NeonatalProgram
  PROGRAM_NAME = 'NEONATAL PROGRAM'

  class Loader
    def load!
      ActiveRecord::Base.transaction do
        concept = find_or_create_concept!
        program = Program.find_or_create_by!(name: PROGRAM_NAME) do |p|
          p.concept_id = concept.concept_id
          p.description = 'Neonatal care program'
          p.creator = creator_id
          p.date_created = Time.now
        end

        puts "Loaded Neonatal program (#{program.program_id}) linked to concept #{concept.concept_id}"
      end
    end

    private

    def find_or_create_concept!
      existing_concept = Concept.joins(:concept_names)
                                .where(concept_name: { name: PROGRAM_NAME })
                                .first
      return existing_concept if existing_concept

      datatype = ConceptDatatype.find_by(name: 'N/A')
      klass = ConceptClass.find_by(name: 'Program')
      raise 'Missing concept datatype (N/A) or concept class (Program)' unless datatype && klass

      concept = Concept.create!(datatype_id: datatype.concept_datatype_id,
                                class_id: klass.concept_class_id,
                                creator: creator_id,
                                date_created: Time.now)

      ConceptName.create!(concept_id: concept.concept_id,
                          name: PROGRAM_NAME,
                          locale: 'en',
                          concept_name_type: 'FULLY_SPECIFIED',
                          creator: creator_id,
                          date_created: Time.now)

      concept
    end

    def creator_id
      @creator_id ||= User.unscoped.order(:user_id).pick(:user_id) || 1
    end
  end
end
