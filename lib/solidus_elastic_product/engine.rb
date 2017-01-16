module SolidusElasticProduct
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'solidus_elastic_product'

    # config.autoload_paths+= %W(#{config.root}/lib)

    initializer "solidus.elastic_product.preferences", :before => :load_config_initializers do |app|
      Spree::BackendConfiguration::CONFIGURATION_TABS << :settings

      config.to_prepare do
        Solidus::ElasticProduct::Config = Solidus::ElasticProduct::Configuration.new
      end
    end

    initializer "solidus.elasticsearch.serializer", :before => :load_config_initializers do |app|
      Elasticsearch::API.settings[:serializer] = Solidus::ElasticProduct::MultiJsonForHashOnly
    end

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
