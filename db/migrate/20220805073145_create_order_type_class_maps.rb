class CreateOrderTypeClassMaps < ActiveRecord::Migration[5.2]
  def change
    create_table :order_type_class_map, id: false do |t|
      t.references :order_type, foreign_key: true
      t.references :concept_class, foreign_key: true
      execute 'ALTER TABLE order_type_class_map ADD PRIMARY KEY (`order_type_id`, `concept_class_id`);'
    end
  end
end
