Spree::Stock::Quantifier.class_eval do

  # Exactly the same as the stock version only it uses the custom relationship
  # instead of a ad-hoc query allowing the data to be pre-loaded.
  def initialize variant
    @variant = variant
    @stock_items = variant.active_stock_items
  end

end
