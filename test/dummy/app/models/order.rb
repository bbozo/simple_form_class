class Order < ActiveRecord::Base
  attr_accessible :order_number, :price, :product_id
end
