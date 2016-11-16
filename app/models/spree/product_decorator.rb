Spree::Product.class_eval do
  # `dependent: :destroy` purposely left off. We don't really want to add a soft
  # delete to the state record (it really inherits the product flag) but the
  # paranoia gem will remove it if we put `dependent: :destroy`
  has_one :elastic_state, class_name: 'Solidus::ElasticProduct::State', inverse_of: :product

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
