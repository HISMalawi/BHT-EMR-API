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
  belongs_to :parent, class_name: 'Observation', optional: true
  has_many :children, class_name: 'Observation', foreign_key: :obs_group_id
  # belongs_to :concept_name, class_name: 'ConceptName', foreign_key: 'concept_name'
  # belongs_to :answer_concept, class_name: 'Concept', foreign_key: 'value_coded'
  # belongs_to(:answer_concept_name, class_name: 'ConceptName',
  #  foreign_key: 'value_coded_name_id')

  has_many :concept_names, through: :concept

  def as_json(options = {})
    super(options.merge(SERIALIZE_OPTIONS))
  end

  def after_void(_reason)
    # HACK: Nullify any attached dispensations
    return unless order_id

    drug_order = DrugOrder.find_by(order_id: order_id)
    return unless drug_order

    drug_order.quantity = nil
  end
end
