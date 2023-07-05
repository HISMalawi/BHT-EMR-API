# frozen_string_literal: true

module TBQueries
  class PersonDrugsQuery
    include ModelUtils

    def initialize(relation = Person.all)
      @relation = relation.extending(Scopes)
    end

    def search
      @relation
    end

    module Scopes
      def started_cpt(start_date, end_date)
        medication_orders_concept = concept('Medication Orders').concept_id
        cpt_concept = concept('Cotrimoxazole').concept_id
        type = encounter_type('Treatment').encounter_type_id
        program = program('TB Program')

        ActiveRecord::Base.connection.select_all(
          <<~SQL
            SELECT person_id FROM (
              SELECT person.person_id, COUNT(*) AS num, obs.date_created FROM person
              JOIN obs ON person.person_id = obs.person_id JOIN encounter ON person.person_id = encounter.patient_id
              WHERE obs.concept_id = '#{medication_orders_concept}' AND obs.value_drug = '#{cpt_concept}'
              AND encounter.encounter_type = '#{type}' AND encounter.program_id = '#{program.program_id}'
              GROUP BY person_id HAVING num = 1
            ) AS cpt_orders WHERE date_created BETWEEN '#{start_date}' AND '#{end_date}'
          SQL
        )
      end
    end
  end
end
