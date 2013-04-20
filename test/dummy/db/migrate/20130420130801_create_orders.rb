class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.integer :product_id
      t.string :order_number
      t.integer :price

      t.timestamps
    end
  end
end
