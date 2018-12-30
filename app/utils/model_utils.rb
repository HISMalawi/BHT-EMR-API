# frozen_string_literal: true
module ModelUtils
  # Retrieve concept by its name
  #
  # Parameters:
  #  name - A string repr of the concept name
  def concept(name)
    Concept.joins(:concept_names).where('concept_name.name = ?', name).first
  end

  def program(name)
    program_name = concept name
    Program.find_by_concept_id program_name.concept_id
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

  def order_type(name)
    OrderType.find_by_name(name)
  end

  def report_type(name)
    ReportType.find_by_name(name)
  end

  def patient_identifier_type(name)
    PatientIdentifierType.find_by_name(name)
  end
end
