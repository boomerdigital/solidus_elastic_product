module Solidus::ElasticProduct
  class Configuration < Spree::Preferences::Configuration
    preference :incremental_update_enabled, :boolean, default: true

    # Allows to provide your own class for generating the json
    # representation of a product
    #
    # @!attribute [rw] serializer_class
    # @return [Class] a class with the same public interfaces
    #   as Solidus::ElasticProduct::Product::Serializer.
    attr_writer :serializer_class
    def serializer_class
      @serializer_class ||= Serializer
    end
  end
end
