# frozen_string_literal: true

# Investigation Service
module RadiologyService
  # Investigation Class
  class Investigation
    def initialize(patient_id, date)
      @pateint = Patient.find(patient_id)
      @date = date
    end

    def self.radiology_concept_set(key)
      case key.class.to_s
      when 'String'
        values = ConceptSet.find_members_by_name(key)
      when 'Integer'
        values = ConceptSet.where(concept_set: key)
      end

      values.map do |concept_set|
        { id: concept_set.concept_id, name: concept_set.concept.fullname }
      end
    end
  end
end
