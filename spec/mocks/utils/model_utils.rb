# frozen_string_literal: true

module ModelUtils
  def concept(_name)
    clazz = Class.new do
      def concept_id
        0
      end
    end

    clazz.new
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
