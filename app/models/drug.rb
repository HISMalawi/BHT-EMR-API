# frozen_string_literal: true

class Drug < ActiveRecord::Base
  self.table_name = :drug
  self.primary_key = :drug_id

  belongs_to :concept
  belongs_to :form, foreign_key: 'dosage_form', class_name: 'Concept'

  has_one :drug_cms, foreign_key: :drug_inventory_id
  has_many :barcodes, class_name: 'DrugOrderBarcode'
  has_many :alternative_names, class_name: 'AlternativeDrugName', foreign_key: 'drug_inventory_id'
  has_many :ntp_regimens, class_name: 'NtpRegimen'

  def self.find_all_by_concept_set(concept_name)
    concept = ConceptName.where(name: concept_name).select(:concept_id)
    concept_set = ConceptSet.where(set: concept).select(:concept_id)
    Drug.where(concept: concept_set)
  end

  def self.arv_drugs
    find_all_by_concept_set('Antiretroviral drugs')
  end

  def as_json(options = {})
    super(options.merge(
      include: {
        alternative_names: {},
        barcodes: {}
      }
    ))
  end

  def arv?
    Drug.arv_drugs.where(drug_id:).exists?
  end

  def tb_drug?
    Drug.tb_drugs.map(&:concept_id).include?(concept_id)
  end

  def self.tb_drugs
    tb_drugs_concept = ConceptName.find_by(name: 'TUBERCULOSIS DRUGS').concept_id
    concepts = ConceptSet.where('concept_set = ?', tb_drugs_concept).map(&:concept_id)
    concepts_placeholders = "(#{(['?'] * concepts.size).join(', ')})"
    Drug.where("concept_id in #{concepts_placeholders}", *concepts)
  end

  def self.first_line_tb_drugs
    first_line_concept = ConceptName.find_by(name: 'First-line tuberculosis drugs').concept_id
    concepts = ConceptSet.where('concept_set = ?', first_line_concept).map(&:concept_id)
    concepts_placeholders = "(#{(['?'] * concepts.size).join(', ')})"
    Drug.where("concept_id in #{concepts_placeholders}", *concepts)
  end

  def self.second_line_tb_drugs
    second_line_concept = ConceptName.find_by(name: 'Second line TB drugs').concept_id
    concepts = ConceptSet.where('concept_set = ?', second_line_concept).map(&:concept_id)
    concepts_placeholders = "(#{(['?'] * concepts.size).join(', ')})"
    Drug.where("concept_id in #{concepts_placeholders}", *concepts)
  end
end
