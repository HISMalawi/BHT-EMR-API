# frozen_string_literal: true

module VMMCService::Reports::Cohort
  class << self
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
  end
end