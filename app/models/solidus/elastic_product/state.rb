# Extends the product to manage the syncronization to elastic

module Solidus::ElasticProduct
  class State < ActiveRecord::Base
    # Expose a configured interface to all of Elastic's instance methods
    # for indexing, i.e. #index_document, #update_document, #delete_document,
    #
    # See {Index} for an interface to all of Elastic's class methods
    # @see elasticsearch-model/lib/elasticsearch/model/indexing.rb#L302
    include Elasticsearch::Model::Indexing::InstanceMethods
    delegate :client, :index_name, :document_type, to: Solidus::ElasticProduct::Index

    self.table_name = 'solidus_elastic_product_states'

    belongs_to :product, -> { with_deleted }, inverse_of: :elastic_state, class_name: "Spree::Product"

    # All products that need serialization not already in queue to be processed.
    #
    # Using a 1 hour lock as serialization is not terribly concurrent or fast so
    # it's possible a job could be pending in the queue for a while.
    scope :needing_serialization, -> { not_locked(:serialization, 1.hour).indexable.where json: nil }

    # All products that need uploading which have been serialized not already in queue to be uploaded
    #
    # Due to the much shorter time and higher level of concurency to upload the
    # locks are not held as long for uploads.
    scope :needing_upload, -> { not_locked(:upload, 20.minutes).serialized_or_excluded.where uploaded: false }

    # Customization points for excluding products from the search index
    #
    scope :indexable,     -> { not_deleted }
    scope :not_indexable, -> { only_deleted }

    # Will mark all the states in the given scope as uploaded. This is done
    # in batch unlike reset! and generate_json! because until the entire batch
    # has been successfully confirmed we cannot mark any done.
    def self.mark_uploaded!
      update_all uploaded: true, locked_for_upload_at: nil
    end

    def self.reset_all!
      update_all json: nil, uploaded: false,
        locked_for_serialization_at: nil, locked_for_upload_at: nil
    end

    # Move the state back to the initial state so all work has to be redone
    # (JSON generated, uploaded, etc). This happens anytime a product changes
    def reset!
      update_attributes! json: nil, uploaded: false,
        locked_for_serialization_at: nil, locked_for_upload_at: nil
    end

    # Generates the JSON representation and clears the lock
    def generate_json!
      indexed_json = Solidus::ElasticProduct::Config.serializer_class.new(product).generate_indexed_json
      update_columns json: indexed_json, locked_for_serialization_at: nil
    end

    # By implementing this method, we get to use the
    # Elasticsearch's indexing instance methods, i.e.
    #
    # @see InstanceMethods#index_document
    # @see InstanceMethods#update_document
    # @see InstanceMethods#delete_document
    def as_indexed_json
      json
    end

    def parsed_json
      JSON.parse(json) if json
    end

  private

    # Support scopes not meant to be used externally
    scope :only_deleted, -> { with_product.where.not Spree::Product.table_name => {deleted_at: nil} }
    scope :not_deleted,  -> { with_product.where Spree::Product.table_name => {deleted_at: nil} }

    scope :serialized, -> { where.not json: nil }

    scope :serialized_or_excluded, -> {
      serialized = unscoped.serialized.where_values.reduce(:and)
      excluded_from_index = unscoped.not_indexable.where_values.reduce(:and)

      with_product.where serialized.or(excluded_from_index)
    }

    scope :not_locked, ->(field, expiration) {
        where \
          "#{table_name}.locked_for_#{field}_at IS NULL OR #{table_name}.locked_for_#{field}_at < ?",
          expiration.ago
    }

    scope :with_product, -> {
      # FIXME: It seems this should be just `joins :product` but the paranioa
      # gem fucks with stuff even though I have a scope applied to relationship
      # above. Reason #395493494 why the paranoia gem is dumb.
      joins "INNER JOIN #{Spree::Product.table_name} ON #{Spree::Product.table_name}.id = #{table_name}.product_id"
    }

  end
end
