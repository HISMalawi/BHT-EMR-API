# frozen_string_literal: true

class StockManagementService
  include ParameterUtils

  # Pharmacy activities (these map to pharmacy_encounter_type.name in the db)
  STOCK_ADD = 'New deliveries'
  STOCK_EDIT = 'Edited stock'
  STOCK_DEBIT = 'Tins removed'

  # Pharmacy activity properties
  REALLOCATION_DESTINATION = 'Transfer out to location'
  REALLOCATION_DRUG = 'Drug getting reallocated'

  # Pharmacy reallocation types
  STOCK_ITEM_DISPOSAL = 'Disposal'
  STOCK_ITEM_REALLOCATION = 'Reallocation'

  # Stock update strategies
  FEFO = 'FEFO' # First expired, first out
  FIFO = 'FIFO' # First in, first out
  LIFO = 'LIFO' # Last in, first out

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
  def add_items_to_batch(batch_number, stock_items)
    ActiveRecord::Base.transaction do
      batch = find_or_create_batch(batch_number)

      stock_items.each_with_index do |item, i|
        drug_id = fetch_parameter(item, :drug_id)
        quantity = fetch_parameter(item, :quantity)

        delivery_date = fetch_parameter_as_date(item, :delivery_date, Date.today)
        expiry_date = fetch_parameter_as_date(item, :expiry_date)

        item = find_batch_items(pharmacy_batch_id: batch.id, drug_id: drug_id,
                                delivery_date: delivery_date, expiry_date: expiry_date).first

        if item
          # Update existing item if already in batch
          item.delivered_quantity += quantity
          item.current_quantity += quantity
          item.save
        else
          item = create_batch_item(batch, drug_id, quantity, delivery_date, expiry_date)
          validate_activerecord_object(item)
        end

        commit_transaction(item, STOCK_ADD, quantity, delivery_date)
      rescue StandardError => e
        raise e.class, "Failed to parse stock item ##{i} due to `#{e.message}`"
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
    query = query.where(filters) unless filters.empty?
    query.order(Arel.sql('date_created DESC, expiry_date ASC'))
  end

  def void_batch(batch_number, reason)
    batch = find_batch_by_batch_number(batch_number)
    batch.items.each { |item| item.void(reason) }
    batch.void(reason)
  end

  def edit_batch_item(batch_item_id, params)
    ActiveRecord::Base.transaction do
      item = PharmacyBatchItem.find(batch_item_id)

      if params[:current_quantity]
        diff = params[:current_quantity].to_f - item.current_quantity
        commit_transaction(item, STOCK_EDIT, diff, Date.today, update_item: false)
      end

      if params[:delivered_quantity]
        diff = params[:delivered_quantity].to_f - item.delivered_quantity
        commit_transaction(item, STOCK_EDIT, diff, Date.today, update_item: true)
      end

      unless item.update(params)
        error = InvalidParameterError.new('Failed to update batch item')
        error.model_errors = item.errors
        raise error
      end

      item
    end
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

  def reallocate_items(reallocation_code, batch_item_id, quantity, destination_location_id, date)
    ActiveRecord::Base.transaction do
      item = PharmacyBatchItem.find(batch_item_id)

      # A negative sign would result in addition of quantity thus
      # get rid of it as early as possible
      quantity = quantity.to_f.abs
      commit_transaction(item, STOCK_DEBIT, -quantity.to_f, update_item: true)
      destination = Location.find(destination_location_id)
      PharmacyBatchItemReallocation.create(reallocation_code: reallocation_code, item: item,
                                           quantity: quantity, location: destination,
                                           reallocation_type: STOCK_ITEM_REALLOCATION,
                                           date: date, creator: User.current)
    end
  end

  def dispose_item(reallocation_code, batch_item_id, quantity, date)
    ActiveRecord::Base.transaction do
      item = PharmacyBatchItem.find(batch_item_id)
      quantity = quantity.to_f.abs
      commit_transaction(item, STOCK_DEBIT, -quantity.to_f, update_item: true)
      PharmacyBatchItemReallocation.create(reallocation_code: reallocation_code, item: item,
                                           quantity: quantity, date: date,
                                           reallocation_type: STOCK_ITEM_DISPOSAL,
                                           creator: User.current)
    end
  end

  def commit_transaction(batch_item, event_name, quantity, date = nil, update_item: false)
    ActiveRecord::Base.transaction do
      date ||= Date.today

      event = validate_activerecord_object(
        Pharmacy.create(item: batch_item, value_numeric: quantity,
                        type: pharmacy_event_type(event_name),
                        encounter_date: date)
      )

      return { event: event, target_item: batch_item } unless update_item

      initial_current_quantity = batch_item.current_quantity
      batch_item.current_quantity += quantity.to_f

      if batch_item.current_quantity.negative?
        raise InvalidParameterError, <<~ERROR
          Debit quantity (#{quantity.abs}) exceeds current quantity (#{initial_current_quantity}) on item ##{batch_item.id}
        ERROR
      end

      batch_item.save
      validate_activerecord_object(batch_item)

      { event: event, target_item: batch_item }
    end
  end

  def update_batch_items(activity, drug_id, quantity, date)
    items = find_batch_items(drug_id: drug_id).where('expiry_date > ?', date)
    stock_items_update_method(activity).call(items, quantity, date)
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

  STOCK_UPDATE_METHODS = {
    # TODO: Refactor the objects defined here in own classes perhaps...
    FEFO => Class.new do
      def debit(stock_service, items, quantity, date)
        items.sort_by(&:expiry_date).each do |item|
          break if quantity.zero?

          item_quantity = item.current_quantity
          next if item_quantity.zero?

          if item_quantity >= quantity
            # No need to spread the quantity across multiple items...
            # This item alone can satisfy the quantity.
            stock_service.commit_transaction(item, StockManagementService::STOCK_DEBIT,
                                             -quantity, date, update_item: true)
            break
          end

          stock_service.commit_transaction(item, StockManagementService::STOCK_DEBIT,
                                           -item_quantity, date, update_item: true)
          quantity -= item_quantity
        end

        LOGGER.warn("Quantity (#{quantity}) could not be debited from items[0]&.drug_id") if quantity > 0
      end

      def credit(stock_service, items, quantity, date)
        item = items.min_by(&:expiry_date)
        stock_service.commit_transaction(item, StockManagementService::STOCK_ADD,
                                         quantity, date, update_item: true)
      end
    end.new,
    FIFO => Object.new do
      def debit(stock_service, items, quantity, date); end

      def credit(stock_service, items, quantity); end
    end,
    LIFO => Object.new do
      def debit(stock_service, items, quantity, date); end

      def credit(stock_service, items, quantity, date); end
    end
  }.freeze

  def find_or_create_batch(batch_number)
    batch = PharmacyBatch.find_by_batch_number(batch_number)
    return batch if batch

    PharmacyBatch.create(batch_number: batch_number)
  end

  def create_batch_item(batch, drug_id, quantity, delivery_date, expiry_date)
    quantity = quantity.to_f

    PharmacyBatchItem.create(
      batch: batch,
      drug_id: drug_id.to_i,
      delivered_quantity: quantity,
      current_quantity: quantity,
      delivery_date: delivery_date,
      expiry_date: expiry_date
    )
  end

  def pharmacy_event_type(event_name)
    type = PharmacyEncounterType.find_by_name(event_name)
    raise NotFoundError, "Pharmacy encounter type not found: #{event_name}" unless type

    type
  end

  def validate_activerecord_object(object)
    return object if object.errors.empty?

    error = InvalidParameterError.new('Failed to create or save object due to bad parameters')
    error.model_errors = object.errors
    raise error
  end

  # Returns a function that takes a list of stock items and quantity then
  # updates the quantity as per configured strategy (ie: FIFO or LIFO or FEFO).
  def stock_items_update_method(activity)
    lambda do |items, quantity, date|
      updater = STOCK_UPDATE_METHODS[configured_stock_maintenance_strategy]

      if activity.match?(/#{STOCK_DEBIT}/i)
        updater.debit(stock_service, items, quantity, date)
      elsif activity.match?(/#{STOCK_ADD}/i)
        updater.credit(stock_service, items, quantity, date)
      else
        raise "Invalid stock update method action: #{action}"
      end
    end
  end

  def configured_stock_maintenance_strategy
    property = GlobalProperty.find_by_property('art.stock.maintenance_strategy')
    property&.property_value&.strip&.upcase || FEFO
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

    total_drugs_consumed = Pharmacy.joins(:item)
                                   .where('(pharmacy_obs.drug_id = :drug_id OR pharmacy_batch_items.drug_id = :drug_id)
                                           AND pharmacy_encounter_type = :event_type AND encounter_date >= :date',
                                          drug_id: drug_id, event_type: STOCK_DEBIT, date: as_of_date)\
                                   .sum(:value_numeric)

    (total_drugs_consumed || 0) / (Date.today - as_of_date).to_i
  end
end
