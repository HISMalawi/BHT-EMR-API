class DiagnosisService
  def find_diagnosis(filters)
    filters = filters.dup # May be modified

    id = filters.delete(:id)
    name = filters.delete(:name)
    query = ConceptName.where("s.concept_set = ?
      AND concept_name.name LIKE (?)", id,
      "%#{name}%").joins("INNER JOIN concept_set s ON
      s.concept_id = concept_name.concept_id").group("concept_name.concept_id")
  end

end
