# frozen_string_literal: true
module ModelUtils
  # Retrieve concept by its name
  #
  # Parameters:
  #  name - A string repr of the concept name
  def concept(name)
    Concept.joins(:concept_names).where('concept_name.name = ?', name).first
  end

  def concept_name(name)
    ConceptName.find_by(name: name)
  end

  def concept_name_to_id(name)
    concept_name(name)&.concept_id
  end

  def program(name)
    Program.find_by_name(name)
  end

  def encounter_type(name)
    EncounterType.find_by name: name
  end

  def global_property(name)
    GlobalProperty.find_by property: name
  end

  def user_property(name, user_id: nil)
    user_id ||= User.current.user_id
    UserProperty.find_by(user_id: user_id, property: name)
  end

  def order_type(name)
    OrderType.find_by_name(name)
  end

  def report_type(name)
    ReportType.find_by_name(name)
  end

  def patient_identifier_type(name)
    PatientIdentifierType.find_by_name(name)
  end

  def drug(name)
    Drug.find_by_name(name)
  end
end
