# frozen_string_literal: true

class Observation < VoidableRecord
  ORDER_SERIALIZE_OPTIONS = { drug_order: {} }.freeze
  CONCEPT_SERIALIZE_OPTIONS = { concept_names: {} }.freeze
  SERIALIZE_OPTIONS = {
    include: {
      concept: { include: CONCEPT_SERIALIZE_OPTIONS },
      order: { include: ORDER_SERIALIZE_OPTIONS },
      children: {
        include: {
          concept: { include: CONCEPT_SERIALIZE_OPTIONS },
          order: { include: ORDER_SERIALIZE_OPTIONS }
        }
      }
    }
  }.freeze

  after_void :after_void

  self.table_name = :obs
  self.primary_key = :obs_id

  belongs_to :encounter, optional: true
  belongs_to :order, optional: true
  belongs_to :concept
  belongs_to :person
  belongs_to :parent, class_name: 'Observation', foreign_key: :obs_group_id, primary_key: :obs_id, optional: true
  has_many :children, class_name: 'Observation', foreign_key: :obs_group_id
  # belongs_to :concept_name, class_name: 'ConceptName', foreign_key: 'concept_name'
  belongs_to :answer_concept, class_name: 'Concept', foreign_key: 'value_coded', optional: true
  # belongs_to(:answer_concept_name, class_name: 'ConceptName',
  #  foreign_key: 'value_coded_name_id')

  has_many :concept_names, through: :concept

  validate :obs_datetime_cannot_be_in_the_future

  # basically we want to ensure the data being saved is sanitized
  def obs_datetime_cannot_be_in_the_future
    return unless obs_datetime > Time.now

    errors.add(:obs_datetime, ' cannot be in the future')
  end

  scope(:for_program, lambda { |program_id|
    return self if program_id.blank?

    joins(:encounter).where(encounter: { program_id: })
  })

  scope(:recent, lambda { |number|
    joins(:encounter).order('obs_datetime DESC,date_created DESC').limit(number)
  })
  scope(:before, lambda { |date|
    where(['obs_datetime < ? ', date]).order('obs_datetime DESC,date_created DESC').limit(1)
  })
  scope(:old, lambda { |number|
    order('obs_datetime DESC,date_created DESC').limit(number)
  })
  scope(:question, lambda { |concept|
    concept_id = concept.to_i
    concept_id = ConceptName.where('name = ?', concept).first&.concept_id || 0 if concept_id.zero?
    where('concept_id = ?', concept_id)
  })

  def as_json(options = {})
    super(options.merge(SERIALIZE_OPTIONS))
  end

  def after_void(_reason)
    # HACK: Nullify any attached dispensations
    return if order_id.nil? || concept_id != ConceptName.find_by_name!('Amount dispensed').concept_id

    drug_order = DrugOrder.find_by(order_id:)
    return unless drug_order

    drug_order.quantity -= value_numeric
    drug_order.save(validate: false)

    StockUpdateJob.perform_now('reverse_dispensation', user_id: User.current.id, location_id: Location.current.id,
                                                       dispensation_id: obs_id)
    # DispensationService.update_stock_ledgers(:reverse_dispensation, self.id)
  end

  def name
    ConceptName.find_by_concept_id(concept_id).name
  end

  def answer_string(tags = [])
    coded_answer_name = begin
      answer_concept.concept_names.typed(tags).first.name
    rescue StandardError
      nil
    end
    coded_answer_name ||= begin
      answer_concept.concept_names.first.name
    rescue StandardError
      nil
    end
    coded_name = "#{coded_answer_name} #{value_modifier}#{value_text} #{value_numeric}#{begin
      value_datetime.strftime('%d/%b/%Y')
    rescue StandardError
      nil
    end}#{value_boolean && begin
      value_boolean == true ? 'Yes' : 'No'
    rescue StandardError
      nil
    end}#{" [#{order}]" if order_id && tags.include?('order')}"
    # the following code is a hack
    # we need to find a better way because value_coded can also be a location - not only a concept
    return coded_name unless coded_name.blank?

    answer = begin
      Concept.find_by_concept_id(value_coded).shortname
    rescue StandardError
      nil
    end

    if answer.nil?
      answer = begin
        Concept.find_by_concept_id(value_coded).fullname
      rescue StandardError
        nil
      end
    end

    if answer.nil?
      answer = begin
        Concept.find_with_voided(value_coded).fullname
      rescue StandardError
        ''
      end
      answer += ' - retired'
    end

    answer
  end
end
