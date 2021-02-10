# frozen_string_literal: true

class Person < VoidableRecord
  after_void :void_related_models

  self.table_name = 'person'
  self.primary_key = 'person_id'

  has_one :patient, foreign_key: :patient_id
  has_many :names, class_name: 'PersonName', foreign_key: :person_id
  has_many :addresses, class_name: 'PersonAddress', foreign_key: :person_id
  has_many :relationships, class_name: 'Relationship', foreign_key: :person_a
  has_many :person_attributes, class_name: 'PersonAttribute', foreign_key: :person_id
  has_many :observations, class_name: 'Observation', foreign_key: :person_id do
    def find_by_concept_name(name)
      concept_name = ConceptName.find_by_name(name)
      conditions = ['concept_id = ?', concept_name.concept_id]
      all(conditions: conditions)
    rescue StandardError => e
      Logger.error "Suppressed exception: #{e}"
      []
    end
  end

  # In an ideal situtation we should be validating birthdate, and gender but
  # unfortunately this same model is used for users. Users do not have these
  # fields set.
  #
  # validates_presence_of :birthdate, :gender

  validates_each :birthdate do |record, attr, value|
    if value && (value < TimeUtils.date_epoch || value > Date.today)
      record.errors.add attr, "#{value} not in range [1920, #{Date.today}]"
    end
  end

  def name
    @name ||= names.max_by(&:date_created)&.to_s
  end

  def as_json(options = {})
    super(options.merge(
      include: {
        names: {},
        addresses: {},
        # relationships: {},
        person_attributes: { methods: %i[type] }
      }
    ))
  end

  def void_related_models(reason)
    names.each { |name| name.void(reason) }
    addresses.each { |address| address.void(reason) }
    relationships.each { |relationship| relationship.void(reason) }
    person_attributes.each { |attribute| attribute.void(reason) }
    # We are going to rely on patient => encounter => obs to void those
  end
end
