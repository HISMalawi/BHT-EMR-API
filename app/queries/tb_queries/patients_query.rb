
  class TBQueries::PatientsQuery
    def initialize (relation = Patient.all)
      @relation = relation.extending(Scopes)
    end

    def search
      @relation
    end

    module Scopes
      def new_patients (start_date, end_date)
        new_patient = concept('New TB Case')

        joins(:encounters => :observations).where(:encounter => { program_id: tb_program,
                                                                  encounter_datetime: start_date..end_date },
                                                  :obs => { value_coded: new_patient })
      end

      def age_range (min, max, start_date, end_date)
        type = encounter_type('TB_Initial')
        joins(:person, :encounters).where('TIMESTAMPDIFF(YEAR, birthdate, NOW()) BETWEEN ? AND ?', min, max)\
                                   .where(encounter: { encounter_type: type, encounter_datetime: start_date..end_date })
      end

      def with_encounters (encounters, start_date, end_date)
        program = program('TB Program')
        filter = encounters_filter(encounters)

        joins(:encounters).where(encounter: { encounter_datetime: start_date..end_date, program_id: program.program_id })\
                          .group(:patient_id)\
                          .having('GROUP_CONCAT(encounter.encounter_type) LIKE ?', filter)
      end

      def without_encounters (encounters, start_date = nil, end_date = nil)
        filter = encounters_filter(encounters)
        where_filter = { :encounter => { program_id: tb_program.program_id } }
        where_filter[:encounter][:encounter_datetime] = (start_date..end_date) if (start_date && end_date)

        joins(:encounters).where(where_filter)\
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

      private

      def tb_program
        program('TB Program')
      end
    end
  end