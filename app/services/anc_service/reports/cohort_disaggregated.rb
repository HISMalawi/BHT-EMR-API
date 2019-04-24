# frozen_string_literal: true

module ANCService
  module Reports
    class CohortDisaggregated
      def initialize(name:, type:, start_date:, end_date:, rebuild:)
        @name = name
        @type = type
        @start_date = start_date
        @end_date = end_date
        @rebuild = rebuild
        @age_groups = ["<10","10-14","15-19","20-24","25-29","30-34",
          "35-39","40-49","50+" ]
        @patients = monthly_registrations(@start_date, @end_date)
      end

      def find_report
        build_report
      end

      def build_report
        builder = CohortDisaggregatedBuilder.new
        builder.build(nil, @start_date, @end_date)
      end

      def initialize_disaggregated

        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_disaggregated')

        ActiveRecord::Base.connection.execute(
          'CREATE TABLE IF NOT EXISTS temp_disaggregated (
             patient_id INTEGER PRIMARY KEY,
             age_group VARCHAR(20),
             maternal_status VARCHAR(10),
             given_ipt INT(1),
             screened_for_tb INT(1)
          ) ENGINE=MEMORY;'
        )

        return {temp_disaggregated: 'created'}
      end

      def disaggregated(date, start_date, end_date)

        results = {}

        month = @start_date.to_date.strftime("%b %Y")

        results[month] = {}
        results[month]["Already on ART"] = getPatientsAreadyOnART()
        results[month]["Newly on ART"] = getPatientsNewlyOnART()
        results[month]["New ANC client"] = getNewClients()
        results[month]["Newly identified negative"] = getPatientsNewlyNegative()
        results[month]["Newly identified positive"] = getPatientsNewlyPositive()
        results[month]["Known status"] = getPatientsWithKnownStatus()
        results[month]["Known at entry positive"] = getPatientsAlreadyPositive()

        return results
      end

      def monthly_registrations(start_date, end_date)

      current_pregnancy_id = EncounterType.find_by_name('Current Pregnancy').id
      lmp_concept_id = ConceptName.find_by_name('Date of Last Menstrual Period').concept_id

      Encounter.where(['encounter_type = ? AND obs.concept_id = ?
          AND DATE(encounter_datetime) >= ?
          AND DATE(encounter_datetime) <= ?
          AND encounter.voided = 0',
        current_pregnancy_id,lmp_concept_id,
        start_date,end_date])
        .joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
        .group([:patient_id])
        .select(['MAX(value_datetime) lmp, patient_id'])
        .collect { |e| e.patient_id }.uniq

    end

      def getNewClients()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        results = Person.find_by_sql(["SELECT *,
          YEAR(date_created) - YEAR(birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(date_created),
          '-', MONTH(birthdate), '-', DAY(birthdate)) ,'%Y-%c-%e') > date_created, 1, 0) AS age
          FROM person WHERE person_id IN (?)", @patients]).collect{|p|
          age = p.age.to_i rescue "unknown";
          person_id = p.person_id

          if (age < 10)
            obj["<10"] << person_id
          elsif (age >=10 && age <=14)
            obj["10-14"] << person_id
          elsif (age > 14 && age <= 19)
            obj["15-19"] << person_id
          elsif (age > 19 && age <= 24)
            obj["20-24"] << person_id
          elsif (age > 24 && age <= 29)
            obj["25-29"] << person_id
          elsif (age > 29 && age <= 34)
            obj["30-34"] << person_id
          elsif (age > 34 && age <= 39)
            obj["35-39"] << person_id
          elsif (age > 39 && age <= 49)
            obj["40-49"] << person_id
          elsif (age > 49)
            obj["50+"] << person_id
          elsif (age == "unknown")
            obj["Unknown"] << person_id
          end

          obj["All"] << person_id
        }

        return obj

      end

      def getPatientsAlreadyPositive()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
        prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

        Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created),
            '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
            e.encounter_datetime AS date FROM encounter e
          INNER JOIN person p ON (p.person_id = e.patient_id)
          INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
          WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
          AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
            OR (o.value_text = 'Positive'))
          AND e.patient_id IN (?)
          AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
            INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
            (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
            WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
            AND DATE(encounter.encounter_datetime) <= ?)
            AND (DATE(e.encounter_datetime) <= ?) AND DATE(e.encounter_datetime) > DATE((SELECT value_text FROM obs
            WHERE encounter_id = e.encounter_id AND obs.concept_id =
            (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)))",
          @patients, @end_date, @end_date]).collect {|e|

            age = e.age.to_i rescue "unknown";
            person_id = e.person_id

            if (age < 10)
              obj["<10"] << person_id
            elsif (age >=10 && age <=14)
              obj["10-14"] << person_id
            elsif (age > 14 && age <= 19)
              obj["15-19"] << person_id
            elsif (age > 19 && age <= 24)
              obj["20-24"] << person_id
            elsif (age > 24 && age <= 29)
              obj["25-29"] << person_id
            elsif (age > 29 && age <= 34)
              obj["30-34"] << person_id
            elsif (age > 34 && age <= 39)
              obj["35-39"] << person_id
            elsif (age > 39 && age <= 49)
              obj["40-49"] << person_id
            elsif (age > 49)
              obj["50+"] << person_id
            elsif (age == "unknown")
              obj["Unknown"] << person_id
            end

            obj["All"] << person_id
          }


        Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created),
            '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age
          FROM encounter e
          INNER JOIN person p ON (p.person_id = e.patient_id)
          INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
          WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Previous HIV Test Results' LIMIT 1)
          AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
            OR (o.value_text = 'Positive'))
          AND e.patient_id IN (?)",@patients]).collect {|e|

          age = e.age.to_i rescue "unknown";
          person_id = e.patient_id

          if (age < 10)
            obj["<10"] << person_id
          elsif (age >=10 && age <=14)
            obj["10-14"] << person_id
          elsif (age > 14 && age <= 19)
            obj["15-19"] << person_id
          elsif (age > 19 && age <= 24)
            obj["20-24"] << person_id
          elsif (age > 24 && age <= 29)
            obj["25-29"] << person_id
          elsif (age > 29 && age <= 34)
            obj["30-34"] << person_id
          elsif (age > 34 && age <= 39)
            obj["35-39"] << person_id
          elsif (age > 39 && age <= 49)
            obj["40-49"] << person_id
          elsif (age > 49)
            obj["50+"] << person_id
          elsif (age == "unknown")
            obj["Unknown"] << person_id
          end

          obj["All"] << person_id
        }

        return obj
      end

      def getPatientsAreadyOnART()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        return obj
      end

      def getPatientsNewlyNegative()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
        prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

        results = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created),
          '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
          e.encounter_datetime AS date, (SELECT value_text FROM obs
          WHERE encounter_id = e.encounter_id AND obs.concept_id =
          (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
        FROM encounter e
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
        WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Negative' LIMIT 1))
          OR (o.value_text = 'Negative'))
        AND e.patient_id IN (?) AND  e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
        INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV Status' LIMIT 1)
        WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
        AND DATE(encounter.encounter_datetime) <= ?) AND (DATE(e.encounter_datetime) <= ?)
        GROUP BY e.patient_id AND DATE(date) = DATE(test_date)",
        @patients, @end_date, @end_date]).collect{|e|

          person_id = e.patient_id
          age = e.age rescue "unknown"

          if (age < 10)
            obj["<10"] << person_id
          elsif (age >=10 && age <=14)
            obj["10-14"] << person_id
          elsif (age > 14 && age <= 19)
            obj["15-19"] << person_id
          elsif (age > 19 && age <= 24)
            obj["20-24"] << person_id
          elsif (age > 24 && age <= 29)
            obj["25-29"] << person_id
          elsif (age > 29 && age <= 34)
            obj["30-34"] << person_id
          elsif (age > 34 && age <= 39)
            obj["35-39"] << person_id
          elsif (age > 39 && age <= 49)
            obj["40-49"] << person_id
          elsif (age > 49)
            obj["50+"] << person_id
          elsif (age == "unknown")
            obj["Unknown"] << person_id
          end

          obj["All"] << person_id
        }

        return obj
      end

      def getPatientsNewlyPositive()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
        prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

        results = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created),
          '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
          e.encounter_datetime AS date, (SELECT value_text FROM obs
          WHERE encounter_id = e.encounter_id AND obs.concept_id =
          (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
        FROM encounter e
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
        WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive'))
        AND e.patient_id IN (?) AND  e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
        INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV Status' LIMIT 1)
        WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
        AND DATE(encounter.encounter_datetime) <= ?)
        AND (DATE(e.encounter_datetime) <= ?) GROUP BY e.patient_id AND DATE(date) = DATE(test_date)",
        @patients, @end_date, @end_date]).collect{|e|

          person_id = e.patient_id
          age = e.age rescue "unknown"

          if (age < 10)
            obj["<10"] << person_id
          elsif (age >=10 && age <=14)
            obj["10-14"] << person_id
          elsif (age > 14 && age <= 19)
            obj["15-19"] << person_id
          elsif (age > 19 && age <= 24)
            obj["20-24"] << person_id
          elsif (age > 24 && age <= 29)
            obj["25-29"] << person_id
          elsif (age > 29 && age <= 34)
            obj["30-34"] << person_id
          elsif (age > 34 && age <= 39)
            obj["35-39"] << person_id
          elsif (age > 39 && age <= 49)
            obj["40-49"] << person_id
          elsif (age > 49)
            obj["50+"] << person_id
          elsif (age == "unknown")
            obj["Unknown"] << person_id
          end

          obj["All"] << person_id
        }

        return obj
      end

      def getPatientsNewlyOnART()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        return obj
      end

      def getPatientsWithKnownStatus()
        obj = {}
        obj["<10"] = []
        obj["10-14"] = []
        obj["15-19"] = []
        obj["20-24"] = []
        obj["25-29"] = []
        obj["30-34"] = []
        obj["35-39"] = []
        obj["40-49"] = []
        obj["50+"] = []
        obj["Unknown"] = []
        obj["All"] = []

        hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id

        prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id


        results = Encounter.find_by_sql(["SELECT distinct e.patient_id,
          YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created),
            '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age
          FROM encounter e INNER JOIN person p ON (p.person_id = e.patient_id)
          INNER JOIN obs o ON (e.encounter_id = o.encounter_id) WHERE e.patient_id in (?)
          AND (o.concept_id = #{hiv_status_concept_id} OR o.concept_id = #{prev_hiv_status_concept_id})
          AND (((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
            OR (o.value_text = 'Positive'))
            OR ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Negative' LIMIT 1))
            OR (o.value_text = 'Negative')))", @patients]).collect {|e|

            person_id = e.patient_id
            age = e.age.to_i #rescue "unknown"

            if (age < 10)
              obj["<10"] << person_id
            elsif (age >=10 && age <=14)
              obj["10-14"] << person_id
            elsif (age > 14 && age <= 19)
              obj["15-19"] << person_id
            elsif (age > 19 && age <= 24)
              obj["20-24"] << person_id
            elsif (age > 24 && age <= 29)
              obj["25-29"] << person_id
            elsif (age > 29 && age <= 34)
              obj["30-34"] << person_id
            elsif (age > 34 && age <= 39)
              obj["35-39"] << person_id
            elsif (age > 39 && age <= 49)
              obj["40-49"] << person_id
            elsif (age > 49)
              obj["50+"] << person_id
            elsif (age == "unknown")
              obj["Unknown"] << person_id
            end

            obj["All"] << person_id
        }

        return obj

      end

    def getANCClientAlreadyOnART(positive_patients, age)

      case age
        when "<10"
          query_condition = "GROUP BY i.patient_id HAVING age < 10"
        when "Unknown Age"
          query_condition = "GROUP BY i.patient_id HAVING age = NULL"
        when "50+"
          query_condition = "GROUP BY i.patient_id HAVING age >= 50"
        when "All"
          query_condition = "GROUP BY i.patient_id"
        else
          raw_age = age.split("-")
          min_age = raw_age[0].to_i
          max_age = raw_age[1].to_i

          query_condition = "GROUP BY i.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      ## Get patients national IDs.
      identifier_type_id = PatientIdentifierType.find_by_name("National ID").id
      sql_query =   "select identifier from patient_identifier "
      sql_query +=  "where patient_id in (?) and identifier_type = ? and voided = '0'"
      patient_npids = PatientIdentifier.find_by_sql([sql_query, positive_patients.map(&:patient_id),
        identifier_type_id]).map(&:identifier)

      ## Gets patient's art start date if exist.
      query =   "SELECT i.identifier, YEAR(p.date_created) - YEAR(p.birthdate) "
      query +=  "- IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), '-', MONTH(p.birthdate), '-', "
      query +=  "DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age FROM patient_identifier i "
      query +=  "INNER JOIN person p ON (p.person_id = i.patient_id)"
      query +=  "INNER JOIN patient_program pg ON i.patient_id = pg.patient_id AND "
      query +=  "pg.program_id = 1 AND pg.voided = 0 "
      query +=  "INNER JOIN patient_state s2 ON s2.patient_state_id = s2.patient_state_id "
      query +=  "AND pg.patient_program_id = s2.patient_program_id "
      query +=  "AND s2.patient_state_id = (SELECT MAX(s3.patient_state_id) FROM patient_state s3 "
      query +=  "WHERE s3.patient_state_id = s2.patient_state_id) "
      query +=  "AND i.voided = 0 AND i.identifier in (?) AND s2.state = 7 "
      query +=  query_condition
      #raise patient_npids.inspect

      bart_on_art = Bart2Connection::PatientIdentifier.find_by_sql([query, patient_npids]).map(&:identifier)

      ## Get anc patient id from national ID
      sql_query =   "select patient_id from patient_identifier where identifier in (?) and voided = 0"
      patient_ids = PatientIdentifier.find_by_sql([sql_query, bart_on_art]).map(&:patient_id) rescue []

      return patient_ids

    end

    def getANCClientNewlyOnART(patient_ids, age, date)

      current_pregnancy_id = EncounterType.find_by_name('Current Pregnancy').id
      lmp_concept_id = ConceptName.find_by_name('Last Menstrual Period').concept_id
      concept_ids = ['Reason for exiting care', 'On ART'].collect{|c| ConceptName.find_by_name(c).concept_id}
      encounter_types = ['LAB RESULTS', 'ART_FOLLOWUP'].collect{|t| EncounterType.find_by_name(t).id}

      results = Encounter.find_by_sql(['SELECT e.patient_id
        FROM encounter e INNER JOIN obs o on o.encounter_id = e.encounter_id
        WHERE e.voided = 0 AND e.patient_id IN (?)
        AND e.encounter_type IN (?) AND o.concept_id IN (?)
        AND DATE(e.encounter_datetime) < ? AND COALESCE(
        (SELECT name FROM concept_name WHERE concept_id = o.value_coded LIMIT 1),
        o.value_text) IN (?)', patient_ids, encounter_types, concept_ids,
        end_date, art_answers]).map(&:patient_id) rescue []

      return results
    end

    def getANCClientsWithHIVPositive(patient_ids)
      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

      results = Encounter.find_by_sql(["SELECT distinct e.patient_id
        FROM encounter e
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON (e.encounter_id = o.encounter_id) WHERE e.patient_id in (?)
        AND (o.concept_id = #{hiv_status_concept_id} OR o.concept_id = #{hiv_status_concept_id})
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive'))", patient_ids])

      return results

    end

    end
  end
end