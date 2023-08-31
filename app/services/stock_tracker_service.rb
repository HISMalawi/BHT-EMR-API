# frozen_string_literal: true

# This class will be used to reconcile stock balances
class StockTrackerService
  # Pharmacy activities (these map to pharmacy_encounter_type.name in the db)
  STOCK_ADD = 'Added'
  STOCK_EDIT = 'Edited'
  STOCK_DEBIT = 'Removed'

  # Pharmacy reallocation types
  STOCK_ITEM_DISPOSAL = 'Disposal'
  STOCK_ITEM_REALLOCATION = 'Reallocation'

  def initialize(drug_id:, pack_size:, transaction_date:, **_kwargs)
    @drug_id = drug_id
    @pack_size = pack_size
    @transaction_date = transaction_date
  end

  # rubocop:disable Metrics/MethodLength
  def update_stock_balance(transaction_type:, quantity:)
    stock = find_stock
    # make the quantiy positive
    quantity = quantity.abs
    case transaction_type
    when STOCK_ADD
      stock.close_balance += quantity
    when STOCK_EDIT
      stock.close_balance += quantity
    else
      stock.close_balance -= quantity
    end
    stock.save
    retrospective_stock_balance(transaction_type: transaction_type, quantity: quantity)
  rescue StandardError => e
    puts "Error updating stock balance: #{e.message}"
  end
  # rubocop:enable Metrics/MethodLength

  private

  # rubocop:disable Metrics/MethodLength
  def retrospective_stock_balance(transaction_type:, quantity:)
    return if @transaction_date == Date.today

    # Update all stock balances from the transaction date to today
    # Use the transaction type to determine whether to add or subtract the quantity

    PharmacyStockBalance.where('transaction_date > ? AND drug_id = ? AND pack_size = ? ', @transaction_date, @drug_id, @pack_size).each do |stock|
      case transaction_type
      when STOCK_ADD
        stock.open_balance += quantity
        stock.close_balance += quantity
      when STOCK_EDIT
        stock.close_balance += quantity
        stock.open_balance += quantity
      else
        stock.close_balance -= quantity
        stock.open_balance -= quantity
      end
      stock.save
    rescue StandardError => e
      puts "Error updating retrospective stock balance: #{e.message}"
    end
  end
  # rubocop:enable Metrics/MethodLength

  def find_stock
    result = PharmacyStockBalance.where(drug_id: @drug_id, pack_size: @pack_size, transaction_date: @transaction_date)&.first
    return result if result

    create_stock
  end

  def create_stock
    # Should create a new stock balance
    # The opening balance and closing balance become the data from the immediate previous transaction
    # The transaction date is the date of the current transaction
    # The drug id and pack size are the same as the current transaction

    # If the immediate previous transaction is not found, then the opening balance and closing balance are both 0
    # The transaction date is the date of the current transaction
    # The drug id and pack size are the same as the current transaction

    prev_stock = PharmacyStockBalance.where('transaction_date < ? AND drug_id = ? AND pack_size = ? ', @transaction_date, @drug_id, @pack_size).order(transaction_date: :desc)&.first
    opening_balance = prev_stock&.close_balance || 0 # || current_record_details
    closing_balance = opening_balance

    PharmacyStockBalance.create(drug_id: @drug_id, pack_size: @pack_size, open_balance: opening_balance, close_balance: closing_balance, transaction_date: @transaction_date)
  rescue StandardError => e
    puts "Error creating stock: #{e.message}"
  end

  # this method is not used because it will give wrong results so it is highly discouraged and should be politically motivated for activation
  def current_record_details
    # get all current balances from PharmacyBatchItem for this particular drug and pack size
    result = PharmacyBatchItem.where(drug_id: @drug_id, pack_size: @pack_size).where('delivery_date < ?', @transaction_date)
    # return the sum of the current quantity
    result.sum(:current_quantity)
  end
end
