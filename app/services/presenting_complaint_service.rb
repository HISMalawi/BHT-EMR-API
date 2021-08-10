class PresentingComplaintService
  def get_complaints(group_concept_id)
    stats = []
    concept_id = ""
    i = 0

    groupData = get_concept_names(group_concept_id)
    (groupData || []).each do |groupRecord|
      stats << {
        group: groupRecord['name'],
        complaints: [],
        concept_id: groupRecord['concept_id'],
      }

      data = get_concept_names(groupRecord['concept_id'])
      (data || []).each do |record|
        stats[i][:complaints] << {
          concept_id: record['concept_id'],
          name: record['name'],
        }
      end

      i += 1
    end

    stats
  end

  def get_concept_names(concept_id)
    ConceptName.where("s.concept_set = ?
    ", concept_id).joins("INNER JOIN concept_set s ON
    s.concept_id = concept_name.concept_id").group("concept_name.concept_id").order(:name)
  end
end