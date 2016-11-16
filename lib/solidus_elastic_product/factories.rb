FactoryGirl.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'solidus_elastic_product/factories'

  # Creating the state directly causes problems as it's attempt to initialize
  # the product will cause it to reset itself. So instead extending product to
  # be created with a pre-defined SB state
  #
  # This really only make sense when calling the create factory.
  factory :product_with_elastic_state, parent: :product do
    transient do
      json nil
      locked_for_serialization_at nil
      uploaded false
      locked_for_upload_at nil
    end

    after(:create) do |product, config|
      state = product.elastic_state
      state.update_attributes! json: config.json,
        locked_for_serialization_at: config.locked_for_serialization_at,
        uploaded: config.uploaded, locked_for_upload_at: config.locked_for_upload_at
    end
  end

  factory :elastic_state, class: "Solidus::ElasticProduct::State" do
    product_id 0 # use dummy value to avoid the above problem
    json nil
    locked_for_serialization_at nil
    uploaded false
    locked_for_upload_at nil
  end

end
