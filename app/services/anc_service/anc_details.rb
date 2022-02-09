# frozen_string_literal: true

module ANCService
  # class managing retrievel of anc patient details
  class ANCDetails
    # method to get DOB of patient
    def self.fetch_dob(database, patient_id)
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT birthdate FROM #{database}.person WHERE person_id = #{patient_id} AND voided = 0
      SQL
      result['birthdate']
    end

    # method to get gender of patient
    def self.fetch_gender(database, patient_id)
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT gender FROM #{database}.person WHERE person_id = #{patient_id} AND voided = 0
      SQL
      result['gender']
    end

    # method to get patient name from the system
    def self.fetch_name(database, patient_id)
      ActiveRecord::Base.connection.select_one <<~SQL
        SELECT given_name, family_name FROM #{database}.person_name WHERE person_id = #{patient_id} AND voided = 0
      SQL
    end

    # method to fetch patient address
    def self.fetch_address(database, patient_id)
      ActiveRecord::Base.connection.select_one <<~SQL
        SELECT * FROM #{database}.person_address WHERE person_id = #{patient_id} AND voided = 0
      SQL
    end

    # method to fetch patient attributes
    def self.fetch_attribute(database, patient_id, type)
      result = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT value FROM #{database}.person_attribute WHERE person_id = #{patient_id} AND person_attribute_type_id = #{type} AND voided = 0
      SQL
      result.blank? ? nil : result['value']
    end
  end
end
