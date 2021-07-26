class Api::V1::ConceptSetsController < ApplicationController
  def realShow
    ConceptName.where("s.concept_set = ?
      AND concept_name.name LIKE (?)", params[:id],
      "%#{params[:name]}%").joins("INNER JOIN concept_set s ON
      s.concept_id = concept_name.concept_id").group("concept_name.concept_id")
  end
  def show

    stats = []
    concept_id = ""
    data = realShow()
    i = 0
    (data || []).each do |record1|

        stats << {
          group: record1['name'],
          complaints: [],
        }

       data2 = ConceptName.where("s.concept_set = ?
      AND concept_name.name LIKE (?)", record1['concept_id'],
      "%%").joins("INNER JOIN concept_set s ON
      s.concept_id = concept_name.concept_id").group("concept_name.concept_id")

      (data2 || []).each do |record|
        stats[i][:complaints] << {
          concept_id: record['concept_id'],
          concept_name_id: record['concept_name_id'],
          concept_name_type: record['concept_name_type'],
          creator: record['creator'],
          date_created: record['date_created'],
          date_voided: record['date_voided'],
          locale: record['locale'],
          locale_preferred: record['locale_preferred'],
          name: record['name'],
          uuid: record['uuid'],
          void_reason: record['void_reason'],
          voided: record['voided'],
          voided_by: record['voided_by'],
        }

      end
      i += 1
    end
    # return stats
    render json: stats
  end

end
