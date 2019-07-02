# frozen_string_literal: true

# A report of LA(1-4) prescribed
class OPDService::Reports::LaPrescriptions
  def find_report(start_date:, end_date:, **_extra_kwargs)
    build_report(start_date, end_date)
  end

  private

  def build_report(start_date, end_date)
    start_date = start_date.to_date.strftime('%Y-%m-%d')
    end_date = end_date.to_date.strftime('%Y-%m-%d')

    if start_date > end_date
      raise InvalidParameterError, "start_date (#{start_date}) can not exceed end_date (#{end_date})"
    end

    # DRUG PRESCRIPTION
    treatment_encounter_type_id = EncounterType.find_by_name('TREATMENT').encounter_type_id
    dispensing_encounter_type_id = EncounterType.find_by_name('DISPENSING').encounter_type_id
    amount_dispensed_concept = Concept.find_by_name('Amount dispensed').id
    drug_order_type_id = OrderType.find_by_name('Drug Order').order_type_id
    program_id = Program.find_by_name('OPD Program')&.program_id
    raise 'OPD Program not found in programs table' unless program_id

    la_one_drug_id = Drug.find_by_name('Lumefantrine + Arthemether 1 x 6').drug_id rescue 0 #Add this drug to meta-data
    la_two_drug_id = Drug.find_by_name('Lumefantrine + Arthemether 2 x 6').drug_id
    la_three_drug_id = Drug.find_by_name('Lumefantrine + Arthemether 3 x 6').drug_id
    la_four_drug_id = Drug.find_by_name('Lumefantrine + Arthemether 4 x 6').drug_id

    prescription_report = {}

    prescription_report['total_la_one_prescribed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) AS total_prescribed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN orders o ON e.encounter_id = o.encounter_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id}
          AND e.program_id = #{program_id}
          AND do.drug_inventory_id = #{la_one_drug_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided = 0
        GROUP BY do.drug_inventory_id
      SQL
    ).last.total_prescribed_drugs rescue 0

    prescription_report['total_la_one_dispensed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM(obs.value_numeric) AS total_dispensed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN obs ON e.encounter_id=obs.encounter_id
          INNER JOIN orders o ON obs.order_id = o.order_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id}
          AND e.program_id = #{program_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND do.drug_inventory_id = #{la_one_drug_id}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND obs.concept_id = #{amount_dispensed_concept}
          AND e.voided = 0
         GROUP BY d.drug_id
      SQL
    ).last.total_dispensed_drugs rescue 0

    prescription_report['total_la_two_prescribed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) AS total_prescribed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN orders o ON e.encounter_id = o.encounter_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id}
          AND e.program_id = #{program_id}
          AND do.drug_inventory_id = #{la_two_drug_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided=0
        GROUP BY do.drug_inventory_id
      SQL
    ).last.total_prescribed_drugs rescue 0

    prescription_report['total_la_two_dispensed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM(obs.value_numeric) AS total_dispensed_drugs FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN obs ON e.encounter_id=obs.encounter_id
          INNER JOIN orders o ON obs.order_id = o.order_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id}
          AND e.program_id = #{program_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND do.drug_inventory_id = #{la_two_drug_id}
          AND obs.concept_id = #{amount_dispensed_concept}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided = 0
        GROUP BY d.drug_id
      SQL
    ).last.total_dispensed_drugs rescue 0

    prescription_report['total_la_three_prescribed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) AS total_prescribed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN orders o ON e.encounter_id = o.encounter_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id}
          AND e.program_id = #{program_id}
          AND do.drug_inventory_id = #{la_three_drug_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
        AND DATE(e.encounter_datetime) <= '#{end_date}'
        AND e.voided=0 GROUP BY do.drug_inventory_id
      SQL
    ).last.total_prescribed_drugs rescue 0

    prescription_report['total_la_three_dispensed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM(obs.value_numeric) AS total_dispensed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN obs ON e.encounter_id=obs.encounter_id
          INNER JOIN orders o ON obs.order_id = o.order_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id}
          AND e.program_id = #{program_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND do.drug_inventory_id = #{la_three_drug_id}
          AND obs.concept_id = #{amount_dispensed_concept}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided = 0
        GROUP BY d.drug_id
      SQL
    ).last.total_dispensed_drugs rescue 0

    prescription_report['total_la_four_prescribed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) AS total_prescribed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN orders o ON e.encounter_id = o.encounter_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id}
          AND e.program_id = #{program_id}
          AND do.drug_inventory_id = #{la_four_drug_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided = 0
        GROUP BY do.drug_inventory_id
      SQL
    ).last.total_prescribed_drugs rescue 0

    prescription_report['total_la_four_dispensed_drugs'] = Order.find_by_sql(
      <<~SQL
        SELECT SUM(obs.value_numeric) as total_dispensed_drugs
        FROM encounter e
          INNER JOIN encounter_type et ON e.encounter_type = et.encounter_type_id
          INNER JOIN obs ON e.encounter_id=obs.encounter_id
          INNER JOIN orders o ON obs.order_id = o.order_id
          INNER JOIN drug_order do ON o.order_id = do.order_id
          INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id}
          AND e.program_id = #{program_id}
          AND o.order_type_id = #{drug_order_type_id}
          AND do.drug_inventory_id = #{la_four_drug_id}
          AND obs.concept_id = #{amount_dispensed_concept}
          AND DATE(e.encounter_datetime) >= '#{start_date}'
          AND DATE(e.encounter_datetime) <= '#{end_date}'
          AND e.voided = 0
        GROUP BY d.drug_id
      SQL
    ).last.total_dispensed_drugs rescue 0

    prescription_report
  end
end
