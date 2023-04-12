# frozen_string_literal: true

# TODO: Move this into ARTService::Pharmacy. Makes sense to have it there since
# this is only for ART.

class StockManagementService
  include ParameterUtils

  # Pharmacy activities (these map to pharmacy_encounter_type.name in the db)
  STOCK_ADD = 'Added'
  STOCK_EDIT = 'Edited'
  STOCK_DEBIT = 'Removed'

  # Pharmacy reallocation types
  STOCK_ITEM_DISPOSAL = 'Disposal'
  STOCK_ITEM_REALLOCATION = 'Reallocation'

  def process_dispensation(dispensation_id)
    dispensation = Observation.find_by(obs_id: dispensation_id)
    raise "Dispensation ##{dispensation_id} not found" unless dispensation

    debit_drug(dispensation_drug_id(dispensation),
               dispensation_pack_size(dispensation),
               dispensation.value_numeric,
               dispensation.obs_datetime,
               'Drug dispensed',
               dispensation_id: dispensation.obs_id)
  end

  def reverse_dispensation(dispensation_id)
    dispensation = Observation.voided.find(dispensation_id)
    raise "*Voided* dispensation ##{dispensation_id} not found" unless dispensation

    Pharmacy.transaction do
      event_log = Pharmacy.where(dispensation_obs_id: dispensation_id, type: pharmacy_event_type(STOCK_DEBIT)).lock!
      reversal_amount = event_log.sum(&:quantity).abs
      return reversal_amount unless reversal_amount.positive?

      amount_rejected = credit_drug(dispensation_drug_id(dispensation),
                                    dispensation_pack_size(dispensation),
                                    reversal_amount,
                                    dispensation.obs_datetime,
                                    "Reversing voided drug dispensation ##{dispensation.id}")

      amount_rejected
    end
  end

  def create_batches(batches)
    ActiveRecord::Base.connection.transaction do
      batches.map do |batch|
        add_items_to_batch(batch[:batch_number], batch[:items], location_id: batch[:location_id])
      end
    end
  end

  # Add list of drugs to stock
  #
  # @param{batch_number} A batch number that came with the drugs package
  # @param{drugs} A list of structures (hashes) containing the stock items
  #               (see description below for the stock item structure).
  #
  # Inventory item structure:
  #       {
  #         drug_id: *integer      # drug_id from Drug model
  #         quantity: *double      # Amount of drugs brought in terms of the drugs atomic unit (eg pills)
  #         expiry_date: *string   # A date conforming to ISO 8601 (ie YYYY-MM-DD)
  #         delivery_date: string  # Similar to above but is not required (defaults to today if not specified)
  #       }
  def add_items_to_batch(batch_number,  stock_items, location_id: nil)
    ActiveRecord::Base.transaction do
      batch = find_or_create_batch(batch_number, location_id: location_id)

      stock_items.each_with_index do |item, i|
        drug_id = fetch_parameter(item, :drug_id)
        quantity = fetch_parameter(item, :quantity)
        barcode = fetch_parameter(item, :barcode)
        product_code = fetch_parameter(item, :product_code)
        pack_size = item[:pack_size]

        delivery_date = fetch_parameter_as_date(item, :delivery_date, Date.today)
        expiry_date = fetch_parameter_as_date(item, :expiry_date)

        item = find_batch_items(pharmacy_batch_id: batch.id,
                                drug_id: drug_id,
                                pack_size: pack_size).first

        if item
          # Update existing item if already in batch
          item.delivered_quantity += quantity
          item.current_quantity += quantity
          item.product_code = product_code
          item.save
        else
          item = create_batch_item(batch, drug_id, pack_size, quantity, delivery_date, expiry_date, product_code)
          validate_activerecord_object(item)
        end

        commit_transaction(item, STOCK_ADD, quantity, delivery_date, transaction_reason: 'Drugs delivered')
      end

      batch
    end
  end

  # Returns an ActiveRecord queryset for retrieving batches on record
  def find_all_batches
    PharmacyBatch.order(date_created: :desc)
  end

  def find_batch_by_batch_number(batch_number)
    batch = PharmacyBatch.find_by_batch_number(batch_number)
    raise NotFoundError, "Batch ##{batch_number} does not exist" unless batch

    batch
  end

  def find_batch_item_by_id(id)
    PharmacyBatchItem.find(id)
  end

  def find_batch_items(filters = {})
    query = PharmacyBatchItem
    unless filters.empty?
      query = query.where("DATE(pharmacy_batch_items.date_created) >= '#{filters[:start_date]}'") if !filters[:start_date].nil?
      query = query.where("DATE(pharmacy_batch_items.date_created) <= '#{filters[:end_date]}'") if !filters[:end_date].nil?
      query = query.where(drug_id: filters[:drug_id]) if !filters[:drug_id].nil?
      query = query.where(current_quantity: filters[:current_quantity]) if !filters[:current_quantity].nil?
      query = query.where(pharmacy_batch_id: filters[:pharmacy_batch_id]) if !filters[:pharmacy_batch_id].nil?
      query = query.where(pack_size: filters[:pack_size]) if !filters[:pack_size].nil?
    end
    query = query.joins("LEFT JOIN pharmacy_obs ON pharmacy_batch_items.id = pharmacy_obs.batch_item_id AND pharmacy_obs.transaction_reason = 'Drug dispensed'")
          .joins("INNER JOIN drug ON drug.drug_id = pharmacy_batch_items.drug_id")
          .group("drug.drug_id")
          .select <<~SQL
              pharmacy_batch_items.*,
              CASE
                WHEN pharmacy_obs.quantity IS NULL
                THEN 0
              ELSE
                ABS(SUM(pharmacy_obs.quantity))
              END AS dispensed_quantity
            SQL
    query.order(Arel.sql('pharmacy_batch_items.date_created DESC, pharmacy_batch_items.expiry_date ASC'))
  end

  def void_batch(batch_number, reason)
    batch = find_batch_by_batch_number(batch_number)
    batch.items.each { |item| item.void(reason) }
    batch.void(reason)
  end

  def edit_batch_item(batch_item_id, params)
    ActiveRecord::Base.transaction do
      process_edit_batch_item(batch_item_id, params)
    end
  end

  def batch_update_items(data)
    ActiveRecord::Base.transaction do
      verification = PharmacyStockVerification.create!(verification_date: data.delete(:verification_date), reason: data.delete(:reason))
      data['items'].map do |item|
        id = item.delete(:id)
        process_edit_batch_item(id, item, verif_id: verification.id)
      end
    end
  end

  def process_edit_batch_item(batch_item_id, params, verif_id: nil)
    item = PharmacyBatchItem.find(batch_item_id)
    reason = params.delete(:reason)

    if params[:current_quantity]
      diff = params[:current_quantity].to_f - item.current_quantity
      commit_transaction(item, STOCK_EDIT, diff, Date.today, update_item: false, transaction_reason: reason, stock_verification_id:verif_id)
    end

    if params[:delivered_quantity]
      diff = params[:delivered_quantity].to_f - item.delivered_quantity
      commit_transaction(item, STOCK_EDIT, diff, Date.today, update_item: true, transaction_reason: reason, stock_verification_id:verif_id)
    end

    unless item.update(params)
      error = InvalidParameterError.new('Failed to update batch item')
      error.model_errors = item.errors
      raise error
    end

    item
  end

  def void_batch_item(batch_item_id, reason)
    item = PharmacyBatchItem.find(batch_item_id)
    item.void(reason)
  end

  def find_earliest_expiring_item(filters = {})
    item = PharmacyBatchItem.where(filters).order(expiry_date: :asc).first
    raise NotFoundError, 'No items found' unless item

    item
  end

  def reallocate_items(reallocation_code, batch_item_id, quantity, destination_location_id, date, reason)
    ActiveRecord::Base.transaction do
      date = date&.to_date || Date.today

      item = PharmacyBatchItem.find(batch_item_id)
      if item.delivery_date > date
        raise InvalidParameterError, "Item was delivered at a date (#{item.delivery_date}) later than relocation date (#{date})"
      end

      # A negative sign would result in addition of quantity thus
      # get rid of it as early as possible
      quantity = quantity.to_f.abs
      commit_transaction(item, STOCK_DEBIT, -quantity.to_f, date, update_item: true, transaction_reason: reason)
      destination = Location.find(destination_location_id)
      PharmacyBatchItemReallocation.create(reallocation_code: reallocation_code, item: item,
                                           quantity: quantity, location: destination,
                                           reallocation_type: STOCK_ITEM_REALLOCATION,
                                           date: date,
                                           date_created: Time.now,
                                           date_changed: Time.now,
                                           creator: User.current.id)
    end
  end

  def dispose_item(reallocation_code, batch_item_id, quantity, date, reason)
    ActiveRecord::Base.transaction do
      item = PharmacyBatchItem.find(batch_item_id)
      quantity = quantity.to_f.abs
      validate_disposal(item, date, reason, quantity)
      commit_transaction(item, STOCK_DEBIT, -quantity.to_f, update_item: true, transaction_reason: reason)
      PharmacyBatchItemReallocation.create(reallocation_code: reallocation_code, item: item,
                                           quantity: quantity, date: date,
                                           reallocation_type: STOCK_ITEM_DISPOSAL,
                                           date_created: Time.now, date_changed: Time.now,
                                           creator: User.current.id)
    end
  end

  def update_batch_item!(batch_item, quantity)
    if quantity.negative? && batch_item.current_quantity < quantity.abs
      raise InvalidParameterError, <<~ERROR
        Debit amount (#{quantity.abs}) exceeds current quantity (#{batch_item.current_quantity}) on item ##{batch_item.id}
      ERROR
    end

    batch_item.with_lock do
      batch_item.current_quantity += quantity.to_f
      batch_item.save
      validate_activerecord_object(batch_item)
    end

    batch_item
  end

  DAYS_IN_MONTH = 30

  # Returns stats for time to drug depletion
  def drug_consumption(drug_id)
    consumption_rate = drug_consumption_rate(drug_id)
    stock_level = drug_stock_level(drug_id)

    stock_level_in_days = consumption_rate.zero? ? DAYS_IN_MONTH : stock_level / consumption_rate
    stock_level_in_months = stock_level_in_days / DAYS_IN_MONTH

    {
      stock_level_in_months: stock_level_in_months,
      stock_level: stock_level,
      consumption_rate: drug_consumption_rate(drug_id)
    }
  end

  private

  def debit_drug(drug_id, pack_size, debit_quantity, date, reason, dispensation_id: nil)
    drugs = find_batch_items(drug_id: drug_id, pack_size: pack_size)
            .where('expiry_date > ? AND current_quantity > 0', date)
            .order('expiry_date')

    commit_kwargs = { update_item: true, dispensation_obs_id: dispensation_id, transaction_reason: reason }

    drugs.each do |drug|
      break if debit_quantity.zero?

      drug.with_lock do
        quantity = [drug.current_quantity, debit_quantity].min
        commit_transaction(drug, STOCK_DEBIT, -quantity, date, **commit_kwargs)
        debit_quantity -= quantity
      end
    end

    debit_quantity
  end

  def credit_drug(drug_id, pack_size, credit_quantity, date, reason)
    return credit_quantity unless credit_quantity.positive?

    drugs = find_batch_items(drug_id: drug_id, pack_size: pack_size)
            .where('delivery_date < :date AND expiry_date > :date AND date_changed >= :date', date: date)
            .order(:expiry_date)

    # Spread the quantity being credited back among the existing drugs,
    # making sure that no drug in stock ends up having more than was
    # initially delivered. BTW: Crediting is done following First to Expire,
    # First Out (FEFO) basis.
    drugs.each do |drug|
      break unless credit_quantity.positive?

      drug_deficit = drug.delivered_quantity - drug.current_quantity
      transaction_amount = credit_quantity > drug_deficit ? drug_deficit : credit_quantity

      commit_transaction(drug, STOCK_ADD, transaction_amount, date, update_item: true, transaction_reason: reason)
      credit_quantity -= transaction_amount
    end

    credit_quantity
  end

  def commit_transaction(batch_item, event_name, quantity, date = nil, update_item: false, **metadata)
    ActiveRecord::Base.transaction do
      event = Pharmacy.create(type: pharmacy_event_type(event_name),
                              item: batch_item,
                              quantity: quantity,
                              transaction_date: date || Date.today,
                              **metadata)
      validate_activerecord_object(event)
      update_batch_item!(batch_item, quantity) if update_item

      { event: event, target_item: batch_item }
    end
  end

  def find_or_create_batch(batch_number, location_id: nil)
    batch = PharmacyBatch.find_by_batch_number(batch_number)
    return batch if batch

    PharmacyBatch.create(batch_number: batch_number, location_id: location_id)
  end

  def create_batch_item(batch, drug_id, pack_size, quantity, delivery_date, expiry_date, product_code)
    quantity = quantity.to_f

    PharmacyBatchItem.create(
      batch: batch,
      drug_id: drug_id.to_i,
      pack_size: pack_size,
      delivered_quantity: quantity,
      current_quantity: quantity,
      delivery_date: delivery_date,
      expiry_date: expiry_date,
      product_code: product_code
    )
  end

  def pharmacy_event_type(event_name)
    type = PharmacyEncounterType.find_by_name(event_name)
    raise NotFoundError, "Pharmacy encounter type not found: #{event_name}" unless type

    type
  end

  # Pulls a drug id from a dispensation observation
  def dispensation_drug_id(dispensation)
    dispensation.value_drug || DrugOrder.find(dispensation.order_id).drug_inventory_id
  end

  # Pulls a pack size from a dispensation observation
  def dispensation_pack_size(dispensation)
    # Currently dispensations on the frontend are made in unit pack sizes (ie
    # each dispensation only has an amount equal to one pack size).
    if PharmacyBatchItem.where(drug_id: dispensation_drug_id(dispensation),
                               pack_size: dispensation.value_numeric)
                        .exists?
      return dispensation.value_numeric
    end

    nil
  end

  # validate disposals
  def validate_disposal(item, date, reason, quantity)
    raise InvalidParameterError, 'Disposal date cannot be in the future' if date > Date.today
    raise InvalidParameterError, 'Disposal date cannot be before the item was delivered' if date < item.delivery_date
    raise InvalidParameterError, 'Disposal reason cannot be blank' if reason.blank?
    raise InvalidParameterError, 'Disposal quantity cannot be blank' if quantity.blank?
    raise InvalidParameterError, 'Disposal quantity cannot be greater than the current quantity' if quantity > item.current_quantity
    raise InvalidParameterError, 'Disposal before expiry date is not allowed' if date < item.expiry_date && reason == 'Expired'
  end

  def validate_activerecord_object(object)
    return object if object.errors.empty?

    error = InvalidParameterError.new("Failed to create or save model `#{object.class}` due to bad parameters")
    error.model_errors = object.errors
    raise error
  end

  # Returns the total amount of drug currently in stock
  def drug_stock_level(drug_id, as_of_date: nil)
    as_of_date ||= Date.today
    PharmacyBatchItem.where('drug_id = ? AND expiry_date >= ?', drug_id, as_of_date)\
                     .sum(:current_quantity)
  end

  DRUG_CONSUMPTION_RATE_INTERVAL = 90 # Period in days to account for in drug consumption rate

  # Returns rate at which drug is being used up.
  def drug_consumption_rate(drug_id, as_of_date: nil)
    # TODO: Implement some sort of caching for this method
    as_of_date ||= DRUG_CONSUMPTION_RATE_INTERVAL.days.ago.to_date

    total_drugs_consumed = Pharmacy.joins(:item, :type)
                                   .where(transaction_date: as_of_date..Float::INFINITY)
                                   .merge(PharmacyBatchItem.where(drug_id: drug_id))
                                   .merge(PharmacyEncounterType.where(name: STOCK_DEBIT))
                                   .select('SUM(ABS(quantity)) AS count')
                                   .first
                                   &.count

    (total_drugs_consumed || 0) / (Date.today - as_of_date).to_i
  end
end
