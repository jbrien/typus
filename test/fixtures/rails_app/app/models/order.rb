class Order < ActiveRecord::Base
  has_one :invoice
end
