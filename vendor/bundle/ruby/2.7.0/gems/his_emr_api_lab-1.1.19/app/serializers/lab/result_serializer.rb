# frozen_string_literal: true

module Lab
  ##
  # Serialize a Lab order result
  module ResultSerializer
    def self.serialize(result)
      result.children.map do |measure|
        value, value_type = read_value(measure)
        concept_name = ConceptName.find_by_concept_id(measure.concept_id)

        {
          id: measure.obs_id,
          indicator: {
            concept_id: concept_name&.concept_id,
            name: concept_name&.name
          },
          date: measure.obs_datetime,
          value: value,
          value_type: value_type,
          value_modifier: measure.value_modifier
        }
      end
    end

    def self.read_value(measure)
      %w[value_numeric value_coded value_boolean value_text].each do |field|
        value = measure.send(field)

        return [value, field.split('_')[1]] if value
      end

      [nil, 'unknown']
    end
  end
end
