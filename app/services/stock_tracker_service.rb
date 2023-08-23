# frozen_string_literal: true

# This class will be used to reconcile stock balances
class StockTrackerService
  TRANSACTION_TYPES = {
    delivery: 'delivery',
    dispensing: 'dispensing',
    adjustment: 'adjustment'
  }.freeze

  def initialize(drug_id:, pack_size:, transaction_date:, **_kwargs)
    @drug_id = drug_id
    @pack_size = pack_size
    @transaction_date = transaction_date
  end

  # rubocop:disable Metrics/MethodLength
  def update_stock_balance(transaction_type:, quantity:)
    stock = find_stock
    case transaction_type
    when TRANSACTION_TYPES[:delivery]
      stock.open_balance += quantity
      stock.close_balance += quantity
    when TRANSACTION_TYPES[:dispensing]
      stock.close_balance -= quantity
    when TRANSACTION_TYPES[:adjustment]
      stock.close_balance += quantity
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

    PharmacyStockBalance.where('transaction_date >= ? AND drug_id = ? AND pack_size = ? ', @transaction_date, @drug_id, @pack_size).each do |stock|
      case transaction_type
      when TRANSACTION_TYPES[:dispensing]
        stock.open_balance -= quantity
        stock.close_balance -= quantity
      else
        stock.open_balance += quantity
        stock.close_balance += quantity
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

    prev_stock = PharmacyStockBalance.where('transaction_date AND drug_id = ? AND pack_size = ? ', @transaction_date, @drug_id, @pack_size).order(transaction_date: :desc)&.first
    opening_balance = prev_stock&.close_balance || 0
    closing_balance = opening_balance

    PharmacyStockBalance.create(drug_id: @drug_id, pack_size: @pack_size, open_balance: opening_balance, close_balance: closing_balance, transaction_date: @transaction_date)
  rescue StandardError => e
    puts "Error creating stock: #{e.message}"
  end
end
