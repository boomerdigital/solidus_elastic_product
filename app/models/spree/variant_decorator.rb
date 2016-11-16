Spree::Variant.class_eval do

  # The same as :stock_items but only includes items in active stock locations.
  # This allows the stock inventory to be preloaded.
  has_many :active_stock_items, -> {
    joins(:stock_location).where spree_stock_locations: {active: true}
  }, class_name: 'Spree::StockItem'

end
