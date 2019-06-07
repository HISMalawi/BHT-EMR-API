# frozen_string_literal: true

class DataCleaningTool

  def initialize(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
  end

  def male_clients_with_female_obs
    concept_ids = []
    concept_ids << concept('BREASTFEEDING').concept_id
    concept_ids << concept('BREAST FEEDING').concept_id
    concept_ids << concept('PATIENT PREGNANT').concept_id
    concept_ids << concept('Family planning method').concept_id

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT 
      p.person_id, given_name, family_name, gender, birthdate,
      i.identifier arv_number
    FROM person p 
    INNER JOIN obs ON obs.person_id = p.person_id AND (p.gender != 'F' AND p.gender != 'Female') 
    LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
    AND i.identifier_type = 4 AND i.voided = 0
    LEFT JOIN person_name n ON n.person_id = p.person_id
    AND n.voided = 0
    WHERE obs.concept_id IN(#{concept_ids.join(',')}) 
    OR value_coded IN(#{concept_ids.join(',')}) 
    AND p.voided = 0 AND obs.voided = 0 GROUP BY p.person_id
    ORDER BY n.date_created DESC;
EOF

    client = []

    (data || []).each do |person|
      client << {
        arv_number: person['arv_number'],
        given_name: person['given_name'],
        family_name: person['family_name'],
        gender: person['gender'],
        birthdate: person['birthdate']
      }
    end

    return client
  end



  private

  def concept(name)
    ConceptName.find_by_name(name)
  end

end
