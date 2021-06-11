class Api::V1::DrugNamesController < ApplicationController
  def OPD_generic_drugs
    concept_set_id = ConceptName.find_by_name 'OPD Medication'
    render json: service.find_generic_drugs(concept_set_id.concept_id)
  end
  def OPD_drugslist
    concept_set_id = ConceptName.find_by_name 'OPD Medication'
    render json: service.find_drug_list(concept_set_id.concept_id)
  end

  private

  def service
    DrugNamesService.new
  end
end
