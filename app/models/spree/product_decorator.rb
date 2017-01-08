Spree::Product.class_eval do
  # `dependent: :destroy` purposely left off. We don't really want to add a soft
  # delete to the state record (it really inherits the product flag) but the
  # paranoia gem will remove it if we put `dependent: :destroy`
  has_one :elastic_state, class_name: 'Solidus::ElasticProduct::State', inverse_of: :product


  # Customization point for excluding properties from the search index.
  # Can be steered for example via boolean flag on Property.
  # Ex: -> { joins(:property).where(indexable: true) }
  #
  has_many :indexable_product_properties, class_name: 'Spree::ProductProperty'

  # Customization point for excluding taxons from the search index.
  # Can for example be used to index only taxons in chosen Taxonomies
  # via a boolean flag on the Taxonomy table.
  #
  has_many :indexable_classifications, class_name: 'Spree::Classification'

  def indexed_popularity
    line_items.count
  end

  private

  # Trigger the state reset so that the manager can notice work needs to be done
  # to resync with SearchBroker.
  def reset_index_state
    elastic_state.reset! if elastic_state && deleted_at.nil?
  end
  after_touch :reset_index_state

  # Every product should have a state record. This ensures this happens at
  # record creation time. The migration ensures it happens to all existing
  # records.
  def create_index_record
    build_elastic_state product: self unless elastic_state
  end
  before_create :create_index_record
end
