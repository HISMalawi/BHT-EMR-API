class DrugNamesService
  def find_generic_drugs(concept_set_id)
    data = ConceptSet.where('concept_set = ? AND concept_name_type = ?',concept_set_id,'FULLY_SPECIFIED').\
      joins('INNER JOIN concept_name cn ON cn.concept_id = concept_set.concept_id').\
      select('concept_set.concept_id, cn.name').\
      order('cn.name ASC').group('cn.concept_id')

      stats = []
      (data || []).each do |record|
        if !record['name'].empty?
        stats << [record['name'],record['concept_id']];
        end
      end
    return stats
  end
  def find_drug_list()
    data = Drug.find_all_by_concept_set('OPD Medication');
      stats = {}
      concept_id = ""
      (data || []).each do |record|

        if(record['concept_id'] != concept_id)
          stats[record['concept_id']] = {}
        end
        concept_id = record['concept_id']
        stats[record['concept_id']]["#{record['name']}"] =  [record['dose_strength'].to_f,record['units']]

      end
      return stats
  end
end