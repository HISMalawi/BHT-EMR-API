module TBQueries
  include ModelUtils

  class PatientsQuery
    def initialize (relation = Patient.all)
      @relation = relation.extending(Scopes)
    end

    def search
      @relation
    end

    module Scopes
      def with_encounters (encounters, start_date, end_date)
        program = program('TB Program')
        filter = encounters_filter(encounters)

        joins(:encounters).where(encounter: { encounter_datetime: start_date..end_date, program_id: program.program_id })\
                          .group(:patient_id)\
                          .having('GROUP_CONCAT(encounter.encounter_type) LIKE ?', filter)
      end

      def or_with_encounters (first, second, start_date, end_date)
        filter_one = encounters_filter(first)
        filter_two = encounters_filter(second)
        program = program('TB Program')

        joins(:encounters).where(encounter: { encounter_datetime: start_date..end_date, program_id: program.program_id })\
                          .group(:patient_id)\
                          .having('GROUP_CONCAT(encounter.encounter_type) LIKE ? OR GROUP_CONCAT(encounter.encounter_type) LIKE ?', filter_one, filter_two)
      end

      def without_encounters (encounters, start_date, end_date)
        filter = encounters_filter(encounters)
        program = program('TB Program')

        joins(:encounters).where(encounter: { encounter_datetime: start_date..end_date, program_id: program.program_id })\
                          .group(:patient_id)\
                          .having('GROUP_CONCAT(encounter.encounter_type) NOT LIKE ?', filter)
      end

      def without_encounters_ever (encounters)
        filter = encounters_filter(encounters)
        program = program('TB Program')

        joins(:encounters).where(encounter: { program_id: program.program_id })\
                          .group(:patient_id)\
                          .having('GROUP_CONCAT(encounter.encounter_type) NOT LIKE ?', filter)
      end

      def with_obs (encounter, name, answer, start_date, end_date)
        type = encounter_type(encounter)
        concept = concept(name)
        value = concept(answer)
        program = program('TB Program')

        joins(:encounters => :observations).where(encounter: { encounter_type: type.encounter_type_id,
                                                               encounter_datetime: start_date..end_date,
                                                               program_id: program.program_id },
                                                  obs: { concept_id: concept.concept_id, value_coded: value.concept_id })
      end

      def with_obs_before (encounter, name, answer, start_date)
        type = encounter_type(encounter)
        concept = concept(name)
        value = concept(answer)
        program = program('TB Program')

        joins(:encounters => :observations).where(encounter: { encounter_type: type.encounter_type_id,
                                                               program_id: program.program_id },
                                                  obs: { concept_id: concept.concept_id, value_coded: value.concept_id })\
                                           .where('encounter.encounter_datetime < ?', start_date)
      end

      def with_obs_ignore_value (encounter, name, start_date, end_date)
        type = encounter_type(encounter)
        concept = concept(name)
        program = program('TB Program')

        joins(:encounters => :observations).where(encounter: { encounter_type: type.encounter_type_id,
                                                               encounter_datetime: start_date..end_date,
                                                               program_id: program.program_id },
                                                  obs: { concept_id: concept.concept_id })
      end

      def some_with_obs (patients, encounter, name, answer)
        type = encounter_type(encounter)
        concept = concept(name)
        value = concept(answer)
        program = program('TB Program')

        joins(:encounters => :observations).where(patient_id: patients,
                                                  encounter: { encounter_type: type.encounter_type_id,
                                                               encounter_datetime: start_date..end_date,
                                                               program_id: program.program_id },
                                                  obs: { concept_id: concept.concept_id, value_coded: value.concept_id })
      end

      def ntp_age_groups (patients_ids)
        ids_as_string = patients_ids.join(',').to_s
        ActiveRecord::Base.connection.select_all(
          <<~SQL
            SELECT
              gender,
              SUM(IF(age <= 4,1,0)) as '0-4',
              SUM(IF(age BETWEEN 5 and 14,1,0)) as '5-14',
              SUM(IF(age BETWEEN 15 and 24,1,0)) as '15-24',
              SUM(IF(age BETWEEN 25 and 34,1,0)) as '25-34',
              SUM(IF(age BETWEEN 35 and 44,1,0)) as '35-44',
              SUM(IF(age BETWEEN 45 and 54,1,0)) as '45-54',
              SUM(IF(age BETWEEN 55 and 64,1,0)) as '55-64',
              SUM(IF(age >=65, 1, 0)) as '65+',
              COUNT(*) AS total
              FROM
                (SELECT TIMESTAMPDIFF(YEAR, birthdate, CURDATE()) AS age, gender FROM person WHERE voided = 0 AND person_id IN (#{ids_as_string}))
            AS groups GROUP BY gender ORDER BY gender;
          SQL
        )
      end

      def encounters_filter (encounters)
        encounters.map { |encounter|
          foo = encounter_type(encounter).encounter_type_id
          "%#{foo}%"
        }.join('')
      end
    end
  end
end