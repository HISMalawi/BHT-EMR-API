class CorrectRfpOrdersAutoExpireDate < ActiveRecord::Migration[5.2]
  def up
    rifapentine_orders.each do |order|
      next unless order.drug_order.weekly_dose?

      run_out_date = order.start_date + order.drug_order.quantity_duration.days - 1.day
      puts "Adjusting RFP order ##{order.order_id} run out date to #{run_out_date} from #{order.auto_expire_date}"

      order.update!(auto_expire_date: run_out_date)
    end
  end

  def down
    rifapentine_orders.each do |order|
      next unless order.drug_order.weekly_dose?

      run_out_date = order.start_date + (order.drug_order.quantity_duration / 7).to_i.days - 1.day
      puts "Resetting RFP order ##{order.order_id} run out date to #{run_out_date} from #{order.auto_expire_date}"

      order.update!(auto_expire_date: run_out_date)
    end
  end

  def rifapentine_orders
    rifapentine = Drug.where(concept_id: ConceptName.where(name: 'Rifapentine').select(:concept_id))
    rifapentine_orders = DrugOrder.joins(:drug).merge(rifapentine).where('quantity > 0')
    treatment_encounters = Encounter.joins(:type, :program)
                                    .merge(EncounterType.where(name: 'Treatment'))
                                    .merge(Program.where(name: 'HIV Program'))

    Order.joins(:encounter, :drug_order)
         .merge(treatment_encounters)
         .merge(rifapentine_orders)
         .includes(:drug_order)
  end
end
