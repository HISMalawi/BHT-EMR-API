class Api::V1::ConceptSetsController < ApplicationController
  def show
    render json: ConceptName.where("s.concept_set = ?
      AND concept_name.name LIKE (?)", params[:id], 
      "%#{params[:name]}%").joins("INNER JOIN concept_set s ON 
      s.concept_id = concept_name.concept_id").group("concept_name.concept_id")
  end
end
