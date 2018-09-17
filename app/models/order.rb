# frozen_string_literal: true

class Order < VoidableRecord
  self.table_name = :orders
  self.primary_key = :order_id

  belongs_to :order_type
  belongs_to :concept
  belongs_to :encounter
  belongs_to :patient
  belongs_to :provider, foreign_key: 'orderer', class_name: 'User'

  validates_presence_of :concept, :concept, :encounter, :patient,
                        :provider

  # has_many :observations
  has_one :drug_order # no default scope

  # named_scope(
  #   :current,
  #   conditions: 'DATE(encounter.encounter_datetime) = CURRENT_DATE()',
  #   include: :encounter
  # )
  # named_scope(
  #   :historical,
  #   conditions: 'DATE(encounter.encounter_datetime) <> CURRENT_DATE()',
  #   include: :encounter
  # )
  # named_scope(
  #   :unfinished,
  #   conditions: ['discontinued = 0 AND auto_expire_date > NOW()']
  # )
  # named_scope(
  #   :finished,
  #   conditions: ['discontinued = 1 OR auto_expire_date < NOW()']
  # )
  # named_scope(
  #   :arv,
  #   lambda do |_order|
  #     arv_concept = ConceptName.find_by_name('ANTIRETROVIRAL DRUGS').concept_id
  #     arv_drug_concepts = ConceptSet.all(
  #       conditions: ['concept_set = ?', arv_concept]
  #     )
  #     { conditions: ['concept_id IN (?)', arv_drug_concepts.map(&:concept_id)] }
  #   end
  # )
  # named_scope(
  #   :labs,
  #   conditions: ['drug_order.drug_inventory_id is NULL'],
  #   include: :drug_order
  # )
  # named_scope(
  #   :prescriptions,
  #   conditions: ['drug_order.drug_inventory_id is NOT NULL'],
  #   include: :drug_order
  # )

  # def self.prescriptions_without_dispensations_data(start_date , end_date)
  #     pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id
  #     arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
  #     national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id

  #     missed_dispensations_data = self.find_by_sql(["SELECT order_id, patient_id, date_created from orders
  #                  WHERE NOT EXISTS (SELECT * FROM obs
  #                  WHERE orders.order_id = obs.order_id AND obs.concept_id = ?)
  #                   AND date_created >= ? AND date_created <= ?", pills_dispensed_id, start_date , end_date ])

  #       prescriptions_without_dispensations = []

  #       missed_dispensations_data.each do |prescription|
  #        drug_id      = DrugOrder.find(prescription[:order_id]).drug_inventory_id
  #        arv_number   = PatientIdentifier.identifier(prescription[:patient_id], arv_number_id).identifier rescue ""
  #        national_id  = PatientIdentifier.identifier(prescription[:patient_id], national_identifier_id).identifier rescue ""
  #        drug_name    = Drug.find(drug_id).name

  #        prescriptions_without_dispensations << [prescription[:patient_id].to_s, arv_number , national_id,
  #                    prescription[:date_created].strftime("%Y-%m-%d %H:%M:%S") , drug_name]
  #       end

  #       prescriptions_without_dispensations
  # end

  # def self.dispensations_without_prescriptions_data(start_date , end_date)
  #     pills_dispensed_id      = ConceptName.find_by_name('PILLS DISPENSED').concept_id
  #     arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
  #     national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id

  #     missed_prescriptions_data = Observation.find(:all, :select:  "person_id, value_drug, date_created",
  #                                                 :conditions:["order_id IS NULL
  #                                                   AND date_created >= ? AND date_created <= ? AND
  #                                                       concept_id = ?" ,start_date , end_date, pills_dispensed_id])

  #       dispensations_without_prescriptions = []

  #       missed_prescriptions_data.each do |dispensation|
  #        drug_name    = Drug.find(dispensation[:value_drug]).name
  #        arv_number   = PatientIdentifier.identifier(dispensation[:person_id], arv_number_id)
  #        national_id  = PatientIdentifier.identifier(dispensation[:person_id], national_identifier_id)

  #        dispensations_without_prescriptions << [dispensation[:person_id].to_s, arv_number[:identifier].to_s, national_id[:identifier].to_s,
  #                    dispensation[:date_created].strftime("%Y-%m-%d %H:%M:%S") , drug_name]
  #       end

  #       dispensations_without_prescriptions
  # end
end
