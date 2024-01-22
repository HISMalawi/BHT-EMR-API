# frozen_string_literal: true

module OpdService
  module Reports
    class Drug
      def find_report(start_date:, end_date:, **_extra_kwargs)
        drug(start_date, end_date)
      end

      def drug(start_date, end_date)
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT#{' '}
            CASE#{' '}
              WHEN LOWER(i.frequency) LIKE '%od%' THEN i.dose * 1 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%bd%' THEN i.dose * 2 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%tds%' THEN i.dose * 3 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qid%' THEN i.dose * 4 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%5x/d%' THEN i.dose * 5 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%q4hrs%' THEN i.dose * 6 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qam%' THEN i.dose * 1 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qnoon%' THEN i.dose * 1 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qpm%' THEN i.dose * 1 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qhs%' THEN i.dose * 1 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qod%' THEN i.dose * 0.5 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%qwk%' THEN i.dose * 0.14 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%once a month%' THEN i.dose * 0.03 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%twice a month%' THEN i.dose * 0.071 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              WHEN LOWER(i.frequency) LIKE '%unknown%' THEN i.dose * 0 * (
                CASE#{' '}
                  WHEN LOWER(o.instructions) LIKE '% for %'#{' '}
                    THEN SUBSTRING(o.instructions, LOCATE('for', o.instructions) + 4)
                  ELSE 1
                END
              )
              ELSE i.dose#{' '}
            END AS prescribe_quantity,(
              SELECT GROUP_CONCAT(c.name SEPARATOR ', ') AS names FROM encounter e#{' '}
              INNER JOIN obs ON obs.encounter_id = e.encounter_id
              INNER JOIN concept_name c ON c.concept_id = obs.value_coded#{' '}
              WHERE e.`voided` = 0 AND (DATE(encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
              AND encounter_type = 8 -- OUTPATIENT DIAGNOSIS
              AND obs.person_id = encounter.patient_id
              AND obs.concept_id IN(6543 -- Secondary diagnosis
                ,6542 -- Primary diagnosis
                ))#{' '}
              AND Date(e.date_created) = DATE(o.date_created)
            ) as diagnosis,
            encounter.patient_id, i.quantity as dispense_quantity,given_name, family_name,
            o.date_created as date, drug_id, o.start_date,p.*, d.name drug_name#{' '}
            FROM `encounter`#{' '}
            INNER JOIN orders o ON o.encounter_id = encounter.encounter_id
            INNER JOIN person p ON p.person_id = encounter.patient_id
            INNER JOIN drug_order i ON i.order_id = o.order_id
            INNER JOIN drug d ON d.drug_id = i.drug_inventory_id
            LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0#{' '}
            WHERE `encounter`.`voided` = 0#{' '}
            AND (DATE(encounter_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
            AND encounter_type = 25 -- TREATMENT
            AND program_id = 14 -- OPD Program
          )#{' '}
            GROUP BY n.person_id, o.order_id ORDER BY n.date_created DESC
        SQL
      end
    end
  end
end
