# frozen_string_literal: true

module ModelUtils
  # Retrieve concept by its name
  #
  # Parameters:
  #  name - A string repr of the concept name
  def concept(name)
    concept_name = ConceptName.find_by name: name
    concept_name ? concept_name.concept : nil
  end

  def encounter(name)
    encounter_type = EncounterType.find_by name: name
    encounter_type ? encounter_type.encounter : nil
  end
end
