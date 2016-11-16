Spree::Taxon.class_eval do

  private

  # This will touch all related products & states. This will allow
  # elastic index to update the products with the updated taxon details.
  def reset_product_index
    taxon_ids = self_and_descendants.pluck(:id)
    Solidus::ElasticProduct::State.joins(product: :classifications).references(:classifications)
      .where(spree_products_taxons: {taxon_id: taxon_ids}).reset_all!
  end

  after_update :reset_product_index, if: -> {
    changed_attributes.except(:lft, :rgt, :updated_at, :depth).present?
  }

  before_destroy :reset_product_index, prepend: true

end
