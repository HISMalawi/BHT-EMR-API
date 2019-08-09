# frozen_string_literal: true

class Concept < RetirableRecord
  self.table_name = :concept
  self.primary_key = :concept_id

  belongs_to :concept_class, foreign_key: :class_id
  belongs_to :concept_datatype, foreign_key: :datatype_id
  has_one :concept_numeric, foreign_key: :concept_id, dependent: :destroy
  # has_one :name, :class_name => 'ConceptName'
  has_many :answer_concept_names, class_name: 'ConceptName'
  has_many :concept_names
  has_many :concept_maps
  has_many :concept_sets
  has_many :concept_answers do
    def limit(search_string)
      return self if search_string.blank?
      map do |concept_answer|
        concept_answer if concept_answer.name.match(search_string)
      end.compact
    end
  end
  has_many :drugs
  has_many :concept_members, class_name: 'ConceptSet', foreign_key: :concept_set

  def self.find_by_name(concept_name)
    Concept.joins(:concept_names).where(["concept_name.name =?", "#{concept_name}"]).first
  end

  def as_json(options = {})
    super(options.merge(
      include: :concept_names
    ))
  end

  def shortname
    name = self.concept_names.typed('SHORT').first.name rescue nil
    return name unless name.blank?
    return self.concept_names.first.name rescue nil
  end

  def fullname
    name = self.concept_names.typed('FULLY_SPECIFIED').first.name rescue nil
    return name unless name.blank?
    return self.concept_names.first.name rescue nil
  end
end
