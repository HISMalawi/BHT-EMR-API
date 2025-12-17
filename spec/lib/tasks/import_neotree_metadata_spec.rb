require 'rails_helper'
require 'neotree_metadata/loader'

RSpec.describe NeotreeMetadata::Loader do
  let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'neotree_metadata', 'sample_metadata.json') }
  subject(:loader) { described_class.new(paths: [fixture_path]) }

  around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  describe '#load!' do
    it 'imports questions and options from metadata' do
      loader.load!

      question = question_concept('TestQuestion')
      expect(question).to be_present

      expect(question.concept_answers.map(&:answer_concept)).to match_array([
        answer_concept('ONE').concept_id,
        answer_concept('TWO').concept_id
      ])

      expect(answer_concept('ONE').concept_names.map(&:name)).to include('Label One')

      expect(question_concept('SecondQuestion')).to be_present
      expect(ConceptAnswer.where(concept: question_concept('SecondQuestion')).count).to eq(1)
    end

    it 'can be re-run without creating duplicates' do
      loader.load!
      answer_count = ConceptAnswer.count

      loader.load!
      expect(ConceptAnswer.count).to eq(answer_count)
    end
  end

  def question_concept(name)
    question_class = ConceptClass.find_by(name: 'Question')
    Concept.joins(:concept_names)
           .where(class_id: question_class.concept_class_id)
           .find_by('concept_name.name = ?', name)
  end

  def answer_concept(name)
    misc_class = ConceptClass.find_by(name: 'Misc')
    Concept.joins(:concept_names)
           .where(class_id: misc_class.concept_class_id)
           .find_by('concept_name.name = ?', name)
  end
end
