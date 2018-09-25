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

  def encounter_type(name)
    EncounterType.find_by name: name
  end

  def global_property(name)
    GlobalProperty.find_by property: name
  end

  def user_property(user_id, name)
    UserProperty.find_by user_id: user_id, property: name
  end
end
