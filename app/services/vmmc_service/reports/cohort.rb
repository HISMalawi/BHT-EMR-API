# frozen_string_literal: true

module VMMCService::Reports::Cohort
  class << self
  	#AGE CATEGORY
    def neonates(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) <= 0 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def first_agegroup(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 0 AND (year(patient_program.date_created) - year(person.birthdate)) <= 14 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def second_agegroup(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 14 AND (year(patient_program.date_created) - year(person.birthdate)) <= 24 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def third_agegroup(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 24 AND (year(patient_program.date_created) - year(person.birthdate)) <= 49 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def fourth_agegroup(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) > 49 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def total_clients(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(patient_program.patient_id)) AS total FROM patient_program LEFT OUTER JOIN person ON person.person_id = patient_program.patient_id LEFT OUTER JOIN program ON program.program_id = patient_program.program_id WHERE (year(patient_program.date_created) - year(person.birthdate)) >= 0 AND program.name = 'VMMC PROGRAM' AND patient_program.voided = 0 AND (patient_program.date_enrolled) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end

    #HIV AND ART STATUS
    def positive_not_art(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9567 and value_coded = 1066 AND obs.person_id IN (select person_id from obs where concept_id = 9569 and value_coded = 9602 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def positive_on_art(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9567 and value_coded = 1065 AND obs.person_id IN (select person_id from obs where concept_id = 9569 and value_coded = 9602 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def negative(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9567 and value_coded = 1066 AND obs.person_id IN (select person_id from obs where concept_id = 9228 and value_coded = 664 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def positive(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9567 and value_coded = 1066 AND obs.person_id IN (select person_id from obs where concept_id = 9228 and value_coded = 703 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def testing_declined(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1066 AND obs.person_id IN (select person_id from obs where concept_id = 9569 and value_coded = 9601 and voided = 0) AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def testing_not_done(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN concept_name ON concept_name.concept_id = obs.concept_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND obs.concept_id = 9568 and value_coded = 1066 AND obs.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    # def eligible_clients(start_date, end_date)
    #   ActiveRecord::Base.connection.select_one(
    #     <<~SQL
    #       SELECT COUNT(DISTINCT(encounter.patient_id)) AS total FROM encounter WHERE encounter.patient_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 39 AND encounter.voided = 0 AND (encounter.encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
    #     SQL
    #   )['total']
    # end

    #Circumcision status
    def circumcision_full(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 9582 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def circumcision_partial(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 8512 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def circumcision_none(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 157 AND obs.concept_id = 9579 and value_coded = 1107 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    #Contraindications status
    def contraindications_none(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 and value_coded = 1066 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def contraindications_yes(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 and value_coded = 1065 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def contraindications_total(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 161 AND obs.concept_id = 9641 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    #Consent status
    def yes_consent(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.value_coded = 1065 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def no_consent(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.value_coded = 1066 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def total_consent(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 162 AND obs.concept_id = 9420 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    #procedures used
    def forceps_guided(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 9608 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def device(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 9610 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
    def others(start_date, end_date)
      ActiveRecord::Base.connection.select_one(
        <<~SQL
          SELECT COUNT(DISTINCT(obs.person_id)) AS total FROM obs LEFT OUTER JOIN encounter ON obs.encounter_id = encounter.encounter_id WHERE obs.person_id IN (SELECT patient_id FROM patient_program where program_id = 21) AND encounter.encounter_type = 158 AND obs.concept_id = 9587 AND obs.value_coded = 6408 AND obs.voided = 0 AND encounter.voided = 0 AND (obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}';
        SQL
      )['total']
    end
  end
end