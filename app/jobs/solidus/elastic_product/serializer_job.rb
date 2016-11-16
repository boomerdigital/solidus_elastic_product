require "solidus/elastic/cache_silencer"

module Solidus::ElasticProduct
  class SerializerJob < ActiveJob::Base
    queue_as :elastic_serializer
    using Config.serializer_class::SerializationIterator
    include CacheSilencer

    # Will update the given products so the json is generated.
    def perform(product_ids)
      return unless Config.incremental_update_enabled

      silence_cache do
        # On my machine it takes about 10-30 seconds to process a batch of products
        # to serialize. Even an overloaded machine having issues should be able
        # to do it in a few minutes.
        Timeout::timeout 5.minutes do
          Spree::Product.where(id: product_ids).each_for_serialization do |product|
            product.elastic_state.generate_json!
          end
        end
      end
    end
  end
end
