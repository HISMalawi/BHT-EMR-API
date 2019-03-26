# frozen_string_literal: true

# A bag of methods imported from NART/app/models/pharmacy.rb and
# NART/app/controllers/generic_drug_controller
#
# FIXME: This entire module might to get re-written... Seems to be doing too
#   much for what it's required to do (besides that, it's reads like noise).
class StockManagementService
  include ParameterUtils

  def create_stocks(stock_obs_list)
    ActiveRecord::Base.transaction do
      stock_obs_list.collect do |obs|
        drug = Drug.find(fetch_parameter(obs, :drug_id)) # Make sure drug id exists in database
        delivery_date = fetch_parameter(obs, :delivery_date).to_date

        # FIXME: The parameter names, :amount and :expire_amount don't make
        #   sense in this context
        if drug_comes_in_packs(drug.name, regimen_name_map)
          number_of_tins = fetch_parameter(obs, :amount).to_f
          number_of_pills_per_tin = fetch_parameter(obs, :expire_amount).to_f
        else
          number_of_tins = fetch_parameter(obs, :expire_amount).to_f
          number_of_pills_per_tin = fetch_parameter(obs, :amount).to_f
        end

        number_of_pills = number_of_tins * number_of_pills_per_tin
        expiry_date = fetch_parameter(obs, :expiry_date)
        barcode = fetch_parameter(obs, :identifier)

        new_delivery(drug.id, number_of_pills, delivery_date, nil, expiry_date,
                     barcode, nil, number_of_pills_per_tin)
      end
    end
  end

  def edit_stock_report(obs_list)
    ActiveRecord::Base.transaction do
      obs_list.collect do |obs|
        drug = Drug.find(fetch_parameter(obs, :drug_id)) # Make sure drug exists
        tins = fetch_parameter(obs, :amount)&.to_i
        pack_size = fetch_parameter(obs, :pills_per_tin)&.to_i || 60

        expiring_units = fetch_parameter(obs, :expire_amount).to_i
        expiry_date = nil

        expiring_units = nil if tins == 0
        expiry_date = nil if tins == 0

        expiry_date = fetch_parameter(obs, :date).to_date.end_of_month if tins.zero?

        if tins == 0 && expiring_units == 0
          pack_size = nil
        end

        delivery_date = fetch_parameter(obs, :delivery_date).to_date
        type = fetch_parameter(obs, :type)
        pills = tins && pack_size ? tins * pack_size : nil

        verified_stock(drug.id, delivery_date, pills, expiry_date, expiring_units, type, pack_size)
      end
    end
  end

  private

  def drug_comes_in_packs(drug, drug_short_names)
    name = drug_short_names[drug]
    name = name&.gsub('(', '')
    name = name&.gsub(')', '')
    splitted = name&.split(' ')
    i = 1
    while (i < splitted.length) do
      if splitted[i].upcase == "ISONIAZID"
        i += 1; next
      end

      if splitted[i].upcase == "OR" or splitted[i].upcase == "H"
        splitted[0] = "#{splitted[0]} #{splitted[i]}"
      end

      i += 1
    end

    return (splitted[0] == 'INH or H' || splitted[0] == 'Cotrimoxazole') ? true : false
  end

  def regimen_name_map
    drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
      'Atazanavir', 'Ritonavir', 'Abacavir', '(', ')', 'Lopinavir', 'Efavirenz', 'Isoniazid'
    ]
    more_regimen = ["LPV/r (Lopinavir and Ritonavir syrup)", "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)", "LPV/r (Lopinavir and Ritonavir 100/25mg tablet)", "EFV (Efavirenz 600mg tablet)", "EFV (Efavirenz 200mg tablet)"]
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    regimen = Regimen.includes(:regimen_drug_orders).where(['program_id = ?', 1]).order("regimen_index") #.to_yaml
    #raise regimen.to_yaml
    regimen = regimen.map do |r|
      if !r.regimen_drug_orders.blank?
        [r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
      else
        []
      end
    end

    @names = {}
    regimen.uniq.each { |r|
      fullname = r
      drug_list.each { |listed|
        r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    more_regimen.each { |r|
      fullname = r
      drug_list.each { |listed|
        r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    other.each { |drug|
      @names[drug] = drug
    }
    return @names

  end

  def total_removed(drug_id, start_date = Date.today, end_date = Date.today)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins removed')

    Pharmacy.where(
      'pharmacy_encounter_type = ? AND drug_id = ? AND encounter_date >= ? AND encounter_date <= ?',
      pharmacy_encounter_type.id, drug_id, start_date, end_date
    ).sum(:value_numeric)
  end

  def drug_dispensed_stock_adjustment(drug_id, quantity, encounter_date, reason = nil, expiring_units = nil)
    encounter_type = PharmacyEncounterType.find_by_name('Tins removed').id if encounter_type.blank?
    encounter = Pharmacy.new
    encounter.pharmacy_encounter_type = encounter_type
    encounter.drug_id = drug_id
    encounter.encounter_date = encounter_date
    encounter.value_numeric = quantity.to_f
    encounter.expiring_units = expiring_units unless expiring_units.blank?
    encounter.value_text = reason unless reason.blank?
    encounter.save

    update_stock_record(drug_id, encounter_date)
    update_average_drug_consumption(drug_id)
  end

  def date_ranges(date)
    current_range = []
    current_range << Report.cohort_range(date).last
    end_date = Report.cohort_range(Date.today).last

    while current_range.last < end_date
      current_range << Report.cohort_range(current_range.last + 1.day).last
    end

    current_range[1..-1]
  end

  def dispensed_drugs_since(drug_id, start_date = Date.today, end_date = Date.today)
    return 0 if start_date.blank? || end_date.blank?

    dispensed_encounter = EncounterType.find_by_name('DISPENSING')
    amount_dispensed_concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    start_date = start_date&.to_date&.strftime('%Y-%m-%d 00:00:00')
    end_date = end_date&.to_date&.strftime('%Y-%m-%d 23:59:59')
    Encounter.joins(:observations).where(
      'concept_id = ? AND encounter_type=? AND obs_datetime >= ?
                      AND obs_datetime <= ? AND value_drug = ?',
      amount_dispensed_concept_id, dispensed_encounter, start_date, end_date, drug_id
    ).sum(:value_numeric)
  end

  def dispensed_drugs_to_date(drug_id)
    dispensed_encounter = EncounterType.find_by_name('DISPENSING')
    amount_dispensed_concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id

    Encounter.joins(:observations).where(
      'concept_id = ? AND encounter_type = ? AND value_drug = ?',
      amount_dispensed_concept_id, dispensed_encounter, drug_id
    ).sum(:value_numeric)
  end

  def current_stock(drug_id)
    current_stock_as_from(drug_id, first_delivery_date(drug_id), Date.today)
  end

  def current_stock_as_from(drug_id, start_date = Date.today, end_date = Date.today)
    total_delivered = total_delivered(drug_id, start_date, end_date)
    total_dispensed = dispensed_drugs_since(drug_id, start_date, end_date)
    total_removed = self.total_removed(drug_id, start_date, end_date)
    (total_delivered - (total_dispensed + total_removed))
  end

  def delivered(drug_id, start_date = Date.today, end_date = Date.today)
    return [] if drug_id.blank? || start_date.blank? || end_date.blank?

    encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id
    Pharmacy.select('value_numeric, value_text, encounter_date AS value_date')\
            .where('pharmacy_encounter_type = ? AND (DATE(encounter_date) BETWEEN (?) AND (?)) AND drug_id = ?',
                   encounter_type, start_date.to_date, end_date.to_date, drug_id)\
            .collect { |del| [del.value_numeric, del.value_date, del.value_text] }
  end

  def new_delivery(drug_id, pills, date = Date.today, encounter_type = nil, expiry_date = nil, barcode = nil, expiring_units = nil, pack_size = 60)
    encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id if encounter_type.blank?
    delivery = Pharmacy.new
    delivery.pharmacy_encounter_type = encounter_type
    delivery.drug_id = drug_id
    delivery.encounter_date = date
    delivery.value_text = barcode
    delivery.pack_size = pack_size
    delivery.expiry_date = expiry_date unless expiry_date.blank?
    delivery.value_numeric = pills.to_f
    delivery.expiring_units = expiring_units if expiring_units
    if expiry_date
      if expiry_date.to_date < Date.today
        delivery.voided = 1
        return delivery.save
      end
    end

    encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    auto_verified_encounter = Pharmacy.new
    auto_verified_encounter.pharmacy_encounter_type = encounter_type
    auto_verified_encounter.drug_id = drug_id
    auto_verified_encounter.encounter_date = date
    auto_verified_encounter.pack_size = pack_size
    auto_verified_encounter.value_numeric = latest_drug_stock(drug_id).to_f + pills.to_f
    auto_verified_encounter.value_text = 'Clinic'

    auto_verified_encounter.expiring_units = expiring_units if expiring_units
    auto_verified_encounter.expiry_date = expiry_date if expiry_date

    delivery.creator = User.current.id
    delivery.date_created = Time.now
    delivery.save
    auto_verified_encounter.creator = User.current.id
    auto_verified_encounter.date_created = Time.now
    auto_verified_encounter.save

    update_stock_record(drug_id, date) # Update stock record
    update_average_drug_consumption(drug_id)
    # raise delivery.to_yaml

    {
      auto_verify_encounter: auto_verified_encounter,
      delivery_encounter: delivery
    }
  end

  def total_delivered(drug_id, start_date = Date.today, end_date = Date.today)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('New deliveries')

    Pharmacy.where('pharmacy_encounter_type = ? AND drug_id = ?
                    AND encounter_date >= ? AND encounter_date <= ?',
                   pharmacy_encounter_type.id, drug_id, start_date, end_date)\
            .sum(:value_numeric)
  end

  def first_delivery_date(drug_id)
    encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id
    Pharmacy.where('drug_id = ? AND pharmacy_encounter_type = ?', drug_id, encounter_type)\
            .order('encounter_date ASC, date_created ASC')\
            .first\
            .encounter_date
  end

  def expiring_drugs(start_date, end_date)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('New deliveries')

    expiring_drugs = Pharmacy.where('pharmacy_encounter_type = ? AND expiry_date >= ? AND expiry_date <= ?',
                                    pharmacy_encounter_type.id, start_date, end_date)

    expiring_drugs_hash = {}
    expiring_drugs.each do |expiring|
      current_stock = current_stock_as_from(expiring.drug_id, first_delivery_date(expiring.drug_id), expiring.encounter_date)
      next if current_stock <= 0

      expiring_drugs_hash["#{expiring.pharmacy_module_id}:#{Drug.find(expiring.drug_id).name}"] = {
        'delivered_stock' => expiring.value_numeric,
        'date_delivered' => expiring.encounter_date,
        'expiry_date' => expiring.expiry_date,
        'current_stock' => current_stock
      }
    end

    expiring_drugs_hash
  end

  def currently_expiring_drugs(start_date, drug_id)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('New deliveries')

    end_date = start_date + 3.months
    expiring_drugs = Pharmacy.where('pharmacy_encounter_type = ? AND expiry_date >= ?
                                     AND expiry_date <= ? AND drug_id = ?',
                                    pharmacy_encounter_type.id, start_date, end_date, drug_id)

    expiring_drugs_hash = {}
    expiring_drugs.each do |expiring|
      current_stock = current_stock_as_from(expiring.drug_id, first_delivery_date(expiring.drug_id), expiring.encounter_date)
      next if current_stock <= 0

      expiring_drugs_hash["#{expiring.pharmacy_module_id}:#{Drug.find(expiring.drug_id).name}"] = {
        'delivered_stock' => expiring.value_numeric,
        'date_delivered' => expiring.encounter_date,
        'expiry_date' => expiring.expiry_date,
        'current_stock' => current_stock
      }
    end

    expiring_drugs_hash
  end

  def removed_from_shelves(start_date, end_date)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins removed')

    removed_from_shelves = Pharmacy.where(
      'pharmacy_encounter_type = ? AND encounter_date >= ? AND encounter_date <= ?',
      pharmacy_encounter_type.id, start_date, end_date
    )

    removed_from_shelves_hash = {}
    (removed_from_shelves || []).each do |removed|
      current_stock = current_stock_as_from(removed.drug_id, first_delivery_date(removed.drug_id), end_date)
      removed_from_shelves_hash["#{removed.pharmacy_module_id}:#{Drug.find(removed.drug_id).name}"] = {
        'amount_removed' => removed.value_numeric,
        'date_removed' => removed.encounter_date,
        'reason' => removed.value_text,
        'current_stock' => current_stock
      }
    end

    removed_from_shelves_hash
  end

  def prescribed_drugs_since(drug_id, start_date, end_date = Date.today)
    treatment_encounter_type = EncounterType.find_by_name('TREATMENT')
    drug_orders = DrugOrder.where(
      'encounter_type = ? AND drug_inventory_id = ? AND encounter_datetime >= ?
                          AND encounter_datetime <= ?',
      treatment_encounter_type.id, drug_id,
      start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
      end_date.to_date.strftime('%Y-%m-%d 23:59:59')
    ).joins(
      'INNER JOIN orders ON drug_order.order_id = orders.order_id
       INNER JOIN encounter e ON e.encounter_id = orders.encounter_id'
    )

    return 0 if drug_orders.blank?

    prescribed_drugs = 0
    drug_orders.each do |drug_order|
      prescribed_drugs += begin
                            (drug_order.duration * drug_order.equivalent_daily_dose)
                          rescue StandardError
                            prescribed_drugs
                          end
    end
    prescribed_drugs
  end

  def total_drug_prescription(drug_id, start_date, end_date = Date.today)
    drug_order = OrderType.find_by_name('Drug Order')
    drug_order_type_id = drug_order.id
    treatment_encounter_type = EncounterType.find_by_name('TREATMENT')
    treatment_encounter_type_id = treatment_encounter_type.id

    total_prescribed = begin
                         ActiveRecord::Base.connection.select_all(
                            "SELECT SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) as total,
                             d.name as DrugName FROM encounter e INNER JOIN encounter_type et
                             ON e.encounter_type = et.encounter_type_id INNER JOIN orders o
                             ON e.encounter_id = o.encounter_id INNER JOIN drug_order do ON o.order_id = do.order_id
                             INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
                             WHERE e.encounter_type = #{treatment_encounter_type_id} AND do.drug_inventory_id = #{drug_id}
                             AND o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{start_date} 00:00:00\"
                             AND e.encounter_datetime <= \"#{end_date} 23:59:59\"
                             AND e.voided=0 GROUP BY do.drug_inventory_id").first['total']
                       rescue StandardError
                         0
                       end
    total_prescribed
  end

  # new code from Bart 10.2

  def alter(drug, quantity, date = nil, reason = nil, auth_code = nil, receiving_facility = nil)
    encounter_type = PharmacyEncounterType.find_by_name('Tins removed').id
    current_stock =  Pharmacy.new
    current_stock.pharmacy_encounter_type = encounter_type
    current_stock.drug_id = drug.id
    current_stock.encounter_date = date
    current_stock.value_numeric = quantity.to_f
    current_stock.value_text = reason
    current_stock.void_reason = 'auth_code:' + auth_code + (receiving_facility.blank? ? '' : ('|relocated_to:' + receiving_facility))
    current_stock.save
    update_stock_record(drug.id, date)
    update_average_drug_consumption(drug.id)
  end

  def relocated(drug_id, start_date, end_date = Date.today)
    encounter_type = PharmacyEncounterType.find_by_name('Tins removed').id
    result = ActiveRecord::Base.connection.select_value <<~SQL
      SELECT sum(value_numeric) FROM pharmacy_obs p
      INNER JOIN pharmacy_encounter_type t ON t.pharmacy_encounter_type_id = p.pharmacy_encounter_type
      AND pharmacy_encounter_type_id = #{encounter_type}
      WHERE p.voided=0 AND drug_id=#{drug_id}
      AND p.encounter_date >='#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      AND p.encounter_date <='#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      GROUP BY drug_id ORDER BY encounter_date
    SQL

    begin
      result.to_i
    rescue StandardError
      0
    end
  end

  def receipts(drug_id, start_date, end_date = Date.today)
    encounter_type = PharmacyEncounterType.find_by_name('New deliveries').id
    result = ActiveRecord::Base.connection.select_value <<~SQL
      SELECT sum(value_numeric) FROM pharmacy_obs p
      INNER JOIN pharmacy_encounter_type t ON t.pharmacy_encounter_type_id = p.pharmacy_encounter_type
      AND pharmacy_encounter_type_id = #{encounter_type}
      WHERE p.voided=0 AND drug_id=#{drug_id}
      AND p.encounter_date >='#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      AND p.encounter_date <='#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      GROUP BY drug_id ORDER BY encounter_date
    SQL

    begin
      result.to_i
    rescue StandardError
      0
    end
  end

  def expected(drug_id, start_date, end_date)
    encounter_type_ids = PharmacyEncounterType.all.collect(&:id)
    start_date = Pharmacy.where('pharmacy_encounter_type IN (?)', encounter_type_ids)\
                         .order('encounter_date ASC, date_created ASC')\
                         .first\
                         .encounter_date || start_date

    dispensed_drugs = dispensed_drugs_since(drug_id, start_date, end_date)
    relocated = relocated(drug_id, start_date, end_date)
    receipts = receipts(drug_id, start_date, end_date)

    receipts - (dispensed_drugs + relocated)
  end

  def verify_closing_stock_count(drug_id, start_date, end_date, type = nil, with_date = false)
    condition = " AND value_text = '#{type}'" unless type.blank?
    encounter_type_id = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    stock = Pharmacy.where(
      "pharmacy_encounter_type = ? AND  encounter_date > ? AND encounter_date <= ?
                                   AND drug_id = ? #{condition}",
      encounter_type_id, start_date, end_date, drug_id
    ).order('encounter_date DESC, date_created DESC').first

    if with_date
      begin
        return [stock.value_numeric, stock.encounter_date]
      rescue StandardError
        [0, nil]
      end
    else
      begin
        return stock.value_numeric
      rescue StandardError
        0
      end
    end
  end

  def verify_stock_count(drug_id, start_date, _end_date, type = nil)
    condition = " AND value_text = '#{type}'" unless type.blank?
    encounter_type_id = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    stock_query = Pharmacy.where('pharmacy_encounter_type = ? AND encounter_date <= ? AND drug_id = ?',
                                 encounter_type_id, start_date, drug_id)
    stock_query.where(value_text: type) unless type.blank?
    stock_query.order('encounter_date DESC,date_created DESC').first&.value_numeric || 0
  end

  def verified_stock(drug_id, date, pills, earliest_expiry = nil, units = nil, type = nil, pack_size = nil)
    encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    encounter = Pharmacy.new
    encounter.pharmacy_encounter_type = encounter_type
    encounter.drug_id = drug_id
    encounter.encounter_date = date
    encounter.pack_size = pack_size
    encounter.value_numeric = pills.to_f
    encounter.expiry_date = earliest_expiry unless earliest_expiry.blank?
    encounter.expiring_units = units unless units.blank?
    encounter.value_text = type unless type.blank?

    encounter.creator = User.current.id
    encounter.date_created = Time.now
    encounter.save

    update_stock_record(drug_id, date)
    update_average_drug_consumption(drug_id)

    encounter
  end

  def current_stock_after_dispensation(drug_id, start_date, end_date = Date.today)
    total_physical_count = latest_physical_counted(drug_id, start_date) # self.total_physically_counted(drug_id, start_date, end_date)
    total_dispensed = dispensed_drugs_since(drug_id, start_date, end_date)
    total_removed = self.total_removed(drug_id, start_date, end_date)
    (total_physical_count - (total_dispensed + total_removed))
  end

  def total_physically_counted(drug_id, start_date, end_date = Date.today)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')

    latest_supervision_type = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * FROM pharmacy_obs p WHERE p.drug_id = #{drug_id}
          AND p.pharmacy_module_id = (
                SELECT MAX(pharmacy_module_id) FROM pharmacy_obs t
                WHERE t.encounter_date = p.encounter_date AND t.drug_id = p.drug_id
                AND t.pharmacy_encounter_type = p.pharmacy_encounter_type
                AND t.encounter_date >= '#{start_date}' AND t.encounter_date <= '#{end_date}'
              )
          AND p.encounter_date = (
              SELECT max(encounter_date) from pharmacy_obs t2
              where t2.encounter_date = p.encounter_date AND t2.drug_id = p.drug_id
              AND t2.pharmacy_encounter_type = p.pharmacy_encounter_type
              AND t2.encounter_date >= '#{start_date}' AND t2.encounter_date <= '#{end_date}'
            ) LIMIT 1
      SQL
    ).last&.value_text # To avoid double count of clinic and supervision data

    Pharmacy.where("pharmacy_encounter_type = ? AND drug_id = ?
                                                AND encounter_date >= ?
                                                AND encounter_date <= ?
                                                AND value_text = '#{latest_supervision_type}'",
                   pharmacy_encounter_type.id, drug_id, start_date, end_date).sum(:value_numeric)
  end

  def latest_physical_counted(drug_id, latest_date)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')

    latest_physical_count = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * FROM pharmacy_obs p
        WHERE p.drug_id = #{drug_id}
          AND p.pharmacy_module_id = (
            SELECT MAX(pharmacy_module_id) FROM pharmacy_obs t
            WHERE t.encounter_date = p.encounter_date
              AND t.drug_id = p.drug_id
              AND t.pharmacy_encounter_type = #{pharmacy_encounter_type.id}
              AND t.encounter_date >= '#{latest_date}'
              AND t.encounter_date <= '#{latest_date}'
          )
          AND p.encounter_date = (
            SELECT max(encounter_date) FROM pharmacy_obs t2
            WHERE t2.encounter_date = p.encounter_date
              AND t2.drug_id = p.drug_id
              AND t2.pharmacy_encounter_type = #{pharmacy_encounter_type.id}
              AND t2.encounter_date >= '#{latest_date}'
              AND t2.encounter_date <= '#{latest_date}'
          )
        LIMIT 1
      SQL
    ).last&.value_numeric || 0 # To avoid double count of clinic and supervision data

    latest_physical_count
  end

  def latest_physical_counted(drug_id, latest_date)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')

    latest_physical_count = begin
                              Pharmacy.find_by_sql(
                                "SELECT * FROM pharmacy_obs p WHERE p.drug_id = #{drug_id}
                                  AND p.pharmacy_module_id = (
                                        SELECT MAX(pharmacy_module_id) FROM pharmacy_obs t
                                        WHERE t.encounter_date = p.encounter_date AND t.drug_id = p.drug_id
                                        AND t.pharmacy_encounter_type = #{pharmacy_encounter_type.id}
                                        AND t.encounter_date >= '#{latest_date}' AND t.encounter_date <= '#{latest_date}'
                                      )
                                  AND p.encounter_date = (
                                      SELECT max(encounter_date) from pharmacy_obs t2
                                      where t2.encounter_date = p.encounter_date AND t2.drug_id = p.drug_id
                                      AND t2.pharmacy_encounter_type = #{pharmacy_encounter_type.id}
                                      AND t2.encounter_date >= '#{latest_date}' AND t2.encounter_date <= '#{latest_date}'
                                    ) LIMIT 1;"
                              ).last.value_numeric
                            rescue StandardError
                              0
                            end # To avoid double count of clinic and supervision data

    latest_physical_count
  end

  def last_physical_count(drug_id, value_text = 'Supervision')
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')
    last_physical_count = begin
                            Pharmacy.find_by_sql(
                              "SELECT * FROM pharmacy_obs p WHERE p.drug_id = #{drug_id}
                                AND p.pharmacy_encounter_type = #{pharmacy_encounter_type.id} AND
                                p.value_text = '#{value_text}' AND
                              DATE(p.encounter_date) = (
                                      SELECT MAX(DATE(t.encounter_date)) FROM pharmacy_obs t
                                      WHERE t.encounter_date = p.encounter_date AND t.drug_id = p.drug_id
                                      AND t.pharmacy_encounter_type = #{pharmacy_encounter_type.id}
                                      AND t.value_text = '#{value_text}'
                                    )"
                            ).last.value_numeric
                          rescue StandardError
                            0
                          end

    last_physical_count
  end

  def current_drug_stock(drug_id)
    # This method gives the current drug stock after latest date of physical count
    # and all dispensation of that particular drug from the latest date of physical count

    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')

    last_physical_count_enc_date = begin
                                     Pharmacy.find_by_sql(
                                       "SELECT * from pharmacy_obs WHERE
                                            drug_id = #{drug_id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id} AND
                                            DATE(encounter_date) = (
                                             SELECT MAX(DATE(encounter_date)) FROM pharmacy_obs
                                             WHERE drug_id =#{drug_id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id}
                                           ) LIMIT 1;"
                                     ).last.encounter_date
                                   rescue StandardError
                                     nil
                                   end
    # total_physical_count = self.total_physically_counted(drug_id, last_physical_count_enc_date)
    total_physical_count = latest_physical_counted(drug_id, last_physical_count_enc_date) # Created a method for pulling latest drug total supervised
    total_dispensed = dispensed_drugs_since(drug_id, last_physical_count_enc_date)
    total_removed = total_removed(drug_id, last_physical_count_enc_date)

    (total_physical_count - (total_dispensed + total_removed))
  end

  def pack_size(drug_id)
    begin
      return DrugCms.find(drug_id).pack_size
    rescue StandardError
      60
    end
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')
    drug_pack_size = begin
                       Pharmacy.find_by_sql(
                         "SELECT * from pharmacy_obs WHERE drug_id = #{drug_id} AND
                             pharmacy_encounter_type = #{pharmacy_encounter_type.id} AND
                              DATE(encounter_date) = (
                               SELECT MAX(DATE(encounter_date)) FROM pharmacy_obs
                               WHERE drug_id =#{drug_id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id}
                             ) LIMIT 1;"
                       ).last.pack_size
                     rescue StandardError
                       60
                     end # if the pack size is not recorded then assume 60 is the pack size. Most drugs come in 60s
    drug_pack_size = 60 if drug_pack_size.blank?
    drug_pack_size
  end

  def update_stock_record(drug_id, encounter_date)
    # Added these methods for the purpose of speed
    edited_stock_encounter_id = PharmacyEncounterType.find_by_name('Edited stock').pharmacy_encounter_type_id
    current_drug_stock = current_drug_stock(drug_id)

    pharmacy_obs = Pharmacy.where(["pharmacy_encounter_type =? AND drug_id =? AND
        value_text = ?", edited_stock_encounter_id, drug_id, 'Current Stock']).last

    if pharmacy_obs.blank?
      pharmacy_obs = Pharmacy.new
      pharmacy_obs.pharmacy_encounter_type = edited_stock_encounter_id
      pharmacy_obs.drug_id = drug_id
      pharmacy_obs.value_text = 'Current Stock'
      pharmacy_obs.creator = User.current.id
      pharmacy_obs.date_created = Time.now
    else
      pharmacy_obs.changed_by = User.current.id
      pharmacy_obs.date_changed = Time.now
    end

    pharmacy_obs.encounter_date = encounter_date
    pharmacy_obs.value_numeric = current_drug_stock.to_i
    pharmacy_obs.save
  end

  def update_average_drug_consumption(drug_id)
    # Added these methods for the purpose of speed
    past_ninety_days_date = (Date.today - 90.days)
    total_drug_dispensations_within_ninety_days = dispensed_drugs_since(drug_id, past_ninety_days_date) # within 90 days
    total_days = (Date.today - past_ninety_days_date).to_i # Difference in days between two dates.
    consumption_rate = (total_drug_dispensations_within_ninety_days / total_days) # Three months average consumption

    edited_stock_encounter_id = PharmacyEncounterType.find_by_name('Edited stock').pharmacy_encounter_type_id
    pharmacy_obs = Pharmacy.where(["pharmacy_encounter_type =? AND drug_id =? AND
        value_text = ?", edited_stock_encounter_id, drug_id, 'Drug Rate']).last

    if pharmacy_obs.blank?
      pharmacy_obs = Pharmacy.new
      pharmacy_obs.pharmacy_encounter_type = edited_stock_encounter_id
      pharmacy_obs.drug_id = drug_id
      pharmacy_obs.value_text = 'Drug Rate'
      pharmacy_obs.creator = User.current.id
      pharmacy_obs.date_created = Time.now
    else
      pharmacy_obs.changed_by = User.current.id
      pharmacy_obs.date_changed = Time.now
    end

    pharmacy_obs.encounter_date = Date.today
    pharmacy_obs.value_numeric = consumption_rate
    pharmacy_obs.save
  end

  def average_drug_consumption(drug_id)
    # Added these methods for the purpose of speed
    edited_stock_encounter_id = PharmacyEncounterType.find_by_name('Edited stock').pharmacy_encounter_type_id
    pharmacy_obs = Pharmacy.where(["pharmacy_encounter_type =? AND drug_id =? AND
        value_text = ?", edited_stock_encounter_id, drug_id, 'Drug Rate']).last
    return pharmacy_obs.value_numeric unless pharmacy_obs.blank?

    0
  end

  def latest_drug_stock(drug_id, date = Date.today)
    # Added these methods for the purpose of speed
    edited_stock_encounter_id = PharmacyEncounterType.find_by_name('Edited stock').pharmacy_encounter_type_id
    pharmacy_obs = Pharmacy.where(["pharmacy_encounter_type =? AND drug_id =? AND
        value_text = ? AND encounter_date <= ?", edited_stock_encounter_id, drug_id, 'Current Stock', date.to_date]).last
    return pharmacy_obs.value_numeric unless pharmacy_obs.blank?

    0
  end

  def latest_drug_rate(drug_id, date = Date.today)
    # Added these methods for the purpose of speed
    edited_stock_encounter_id = PharmacyEncounterType.find_by_name('Edited stock').pharmacy_encounter_type_id
    pharmacy_obs = Pharmacy.where(["pharmacy_encounter_type =? AND drug_id =? AND
        value_text = ? AND encounter_date <= ?", edited_stock_encounter_id, drug_id, 'Drug Rate', date.to_date]).last
    return pharmacy_obs.value_numeric unless pharmacy_obs.blank?

    0
  end

  def physical_verified_stock(drug_id, date)
    encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    verified_stock = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * FROM pharmacy_obs t
        WHERE t.encounter_date = '#{date}'
          AND drug_id = #{drug_id}
          AND t.value_text = 'Supervision'
          AND pharmacy_encounter_type = #{encounter_type}
          AND t.voided = 0
          AND date_created = (
            SELECT MAX(t2.date_created) FROM pharmacy_obs t2
            WHERE t2.encounter_date = '#{date}'
              AND t2.drug_id = #{drug_id}
              AND t2.value_text = 'Supervision'
              AND t2.pharmacy_encounter_type = #{encounter_type} AND t2.voided = 0
          )
        LIMIT 1
      SQL
    ).first

    return [] if verified_stock.blank?

    previous_verified_stock = 0

    unless verified_stock.date_created.blank?
      previous_verified_stock = Pharmacy.find_by_sql(
        <<~SQL
          SELECT t.value_numeric FROM pharmacy_obs t
          WHERE t.encounter_date = '#{date}'
            AND drug_id = #{drug_id}
            AND t.value_text = 'Supervision'
            AND pharmacy_encounter_type = #{encounter_type}
            AND t.voided = 0
            AND date_created = (
              SELECT MAX(t2.date_created) FROM pharmacy_obs t2
              WHERE t2.encounter_date = '#{date}'
                AND t2.drug_id = #{drug_id}
                AND t2.value_text = 'Supervision'
                AND t2.pharmacy_encounter_type = #{encounter_type}
                AND t2.voided = 0
                AND t2.date_created < '#{verified_stock.date_created.to_time.strftime('%Y-%m-%d %H:%M:%S')}'
            )
        SQL
      )

      previous_verified_stock = previous_verified_stock&.value_numeric&.to_f
    end

    { verified_stock: verified_stock.value_numeric,
      expiring_units: verified_stock.expiring_units,
      earliest_expiry_date: verified_stock.expiry_date,
      previous_verified_stock: previous_verified_stock }
  end

  def self.drug_stock_on(drug_id, date = Date.today)
    # This method gives the current drug stock after latest date of physical count
    # and all dispensation of that particular drug from the latest date of physical count

    # total_physical_count = self.total_physically_counted(drug_id, last_physical_count_enc_date)
    physical_count = latest_physical_count(drug_id) # Created a method for pulling latest drug total supervised
    return 0 if physical_count.blank?

    total_physical_count = physical_count.first
    start_date = physical_count.last
    return 0 if start_date > date

    total_dispensed = dispensed_drugs_since(drug_id, start_date, date)
    total_removed = self.total_removed(drug_id, start_date, date)
    count = (total_physical_count - (total_dispensed + total_removed))
    return count if count >= 0

    0
  end

  # ............................... New code to cal latest_physical_counted (meant for ART stock management app).................................#
  def self.latest_physical_count(drug_id)
    encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    #     verified_stock = self.find_by_sql("SELECT * FROM pharmacy_obs t
    #       WHERE t.encounter_date <= current_date() AND drug_id = #{drug_id} AND t.value_text IN('Supervision', 'Clinic')
    #       AND pharmacy_encounter_type = #{encounter_type} AND t.voided = 0
    #       AND encounter_date = (SELECT MAX(t2.encounter_date) FROM pharmacy_obs t2
    #       WHERE t2.encounter_date <= current_date() AND t2.drug_id = #{drug_id} AND t2.value_text IN('Supervision', 'Clinic')
    #       AND t2.pharmacy_encounter_type = #{encounter_type} AND t2.voided = 0) LIMIT 1").first

    latest_date = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * FROM pharmacy_obs
        WHERE drug_id = #{drug_id}
          AND pharmacy_encounter_type = #{encounter_type}
          AND DATE(encounter_date) = (
            SELECT MAX(DATE(encounter_date)) FROM pharmacy_obs
            WHERE drug_id =#{drug_id} AND pharmacy_encounter_type = #{encounter_type}
          )
        LIMIT 1
      SQL
    ).last&.encounter_date

    verified_stock = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * FROM pharmacy_obs p
        WHERE p.drug_id = #{drug_id}
          AND p.pharmacy_module_id = (
            SELECT MAX(pharmacy_module_id) FROM pharmacy_obs t
            WHERE t.encounter_date = p.encounter_date
              AND t.drug_id = p.drug_id
              AND t.pharmacy_encounter_type = #{encounter_type}
              AND t.encounter_date >= '#{latest_date}'
              AND t.encounter_date <= '#{latest_date}'
            )
        AND p.encounter_date = (
            SELECT max(encounter_date) FROM pharmacy_obs t2
            WHERE t2.encounter_date = p.encounter_date
              AND t2.drug_id = p.drug_id
              AND t2.pharmacy_encounter_type = #{encounter_type}
              AND t2.encounter_date >= '#{latest_date}'
              AND t2.encounter_date <= '#{latest_date}'
          ) LIMIT 1
      SQL
    ).last

    return [] if verified_stock.blank?

    [verified_stock.value_numeric, verified_stock.encounter_date]
  end

  def self.latest_expiry_date_for_drug(drug_id)
    pharmacy_encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock')

    last_physical_expiry_date = Pharmacy.find_by_sql(
      <<~SQL
        SELECT * from pharmacy_obs
        WHERE drug_id = #{drug_id}
          AND pharmacy_encounter_type = #{pharmacy_encounter_type.id}
          AND DATE(encounter_date) = (
            SELECT MAX(DATE(encounter_date)) FROM pharmacy_obs
            WHERE drug_id =#{drug_id} AND pharmacy_encounter_type = #{pharmacy_encounter_type.id}
          )
        LIMIT 1
      SQL
    ).last&.expiry_date&.to_date || 0

    last_physical_expiry_date
  end
  # ............................... New code to cal latest_physical_counted (meant for ART stock management app) ends .................................#

end
