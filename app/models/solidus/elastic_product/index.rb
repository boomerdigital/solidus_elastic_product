# This static class exposes a configured interface to all class methods
# available from elastic search. Elastic's instance methods are available
# through {State}.
#
# The available class methods are defined in elasticsearch/model.rb under
# Model::METHODS = [:search, :mapping, :mappings, :settings, :index_name, :document_type, :import]
#
# @see elasticsearch-model/lib/elasticsearch/model/client.rb#L8
# @see elasticsearch-model/lib/elasticsearch/model/naming.rb#L8
# @see elasticsearch-model/lib/elasticsearch/model/indexing.rb#L83
# @see elasticsearch-model/lib/elasticsearch/model/searching.rb#L55

module Solidus::ElasticProduct
  class Index
    extend Elasticsearch::Model::Client::ClassMethods
    extend Elasticsearch::Model::Naming::ClassMethods
    extend Elasticsearch::Model::Indexing::ClassMethods
    extend Elasticsearch::Model::Searching::ClassMethods

    # Indexing is primary performed by the {Uploader}
    #
    # @see elasticsearch-model/lib/elasticsearch/model/adapters/active_record.rb
    extend Elasticsearch::Model::Importing::ClassMethods

    index_name 'products_' + Rails.env
    document_type 'product'

    settings File.open(SolidusElasticProduct::Engine.root + "config/elasticsearch/spree_products.yml")

    options = {
      dynamic_templates: [
        {
          string_template: {
            match: "*",
            match_mapping_type: "string",
            mapping: {
              fields: {
                analyzed: {
                  index: "analyzed",
                  type: "text"
                }
              },
              ignore_above: 256,
              include_in_all: true,
              type: "keyword"
            }
          }
        }
      ]
    }

    mappings(options) do
      indexes :name,          type: 'string', analyzer: 'snowball'
      indexes :taxons,        type: 'nested' do
        indexes :id,          type: 'long'
      end
    end


    # Implement the importing adapter interface
    module Importing
      # Fetch batches of records from the database (used by the import method)
      #
      def __find_in_batches(options={}, &block)
        query = options.delete(:query)
        named_scope = options.delete(:scope)
        preprocess = options.delete(:preprocess)

        scope = State.serialized
        scope = scope.__send__(named_scope) if named_scope
        scope = scope.instance_exec(&query) if query

        scope.find_in_batches(options) do |batch|
          # State might've gotten reset in the meantime, skip those
          batch.delete_if { |state| state.json.blank? }
          yield (preprocess ? self.__send__(preprocess, batch) : batch)
        end
      end

      def __transform
        lambda { |model|
          # JSON.parse is required due to https://github.com/elastic/elasticsearch-rails/issues/606
          # remove once issue is resolved, as it slows down the indexing
          { index: { _id: model.id, data: JSON.parse(model.as_indexed_json) } }
        }
      end
    end

    extend Importing


  end
end
