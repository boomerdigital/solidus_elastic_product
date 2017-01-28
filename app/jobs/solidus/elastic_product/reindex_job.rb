# Creates a new index, populates it with all products, and
# finally swaps the alias to the new index. Non-serialized products
# will not be uploaded. Use Schedule.serialize_all on the first run
# to serialize all products.
# In all other cases, the incremental SerializerJob
# should keep the records serialized.

module Solidus::ElasticProduct
  class ReindexJob < ActiveJob::Base
    queue_as :elastic_uploader

    delegate  :client, :index_name, :document_type,
              :import, :create_index!, to: Index

    def perform
      old_state = Config.incremental_update_enabled
      Config.incremental_update_enabled = false

      new_index_name = index_name + "_" + Time.now.strftime('%Y%m%d%H%M%S%L')
      create_index!(index: new_index_name)

      # Put all data in the new index
      import(index: new_index_name, batch_size: 500) do |response|
        report_on(response)

        # Mark successfully indexed products as uploaded
        ids = response['items'].select { |p| p['index']['error'].nil? }
                               .map { |p| p['index']['_id'] }

        State.where(id: ids).mark_uploaded!
      end

      # Then assign the alias to the new index
      swap(new_index_name)

      # And delete the old index
      cleanup
    ensure
      # Restore to previous value (likely enabled)
      Config.incremental_update_enabled = old_state
    end

  private

    # Moves the alias to the new index, or
    # creates one if an alias doesn't exist yet
    #
    # borrowed from searchkick/lib/searchkick/index.rb:190
    def swap(new_name)
      actions = []

      if client.indices.exists_alias(name: index_name)
        old_index_names = client.indices.get_alias(name: index_name).keys
        actions += old_index_names.map do |old_name|
          { remove: { index: old_name, alias: index_name } }
        end
      end

      actions += [{ add: { index: new_name, alias: index_name } }]
      client.indices.update_aliases body: { actions: actions }
    end

    def report_on(response)
      if response["errors"]
        Rails.logger.error "ElasticProduct: Failed to perform reindex for some products"
        response['items'].select { |item| item.key?('error') }.each do |item|
          Rails.logger.error item.to_s
        end
      else
        Rails.logger.info "ElasticProduct: Reindexed successfully in #{response['took']} ms"
      end
    end

    # Remove old indices that start with index_name
    #
    # borrowed from searchkick/lib/searchkick/index.rb:167
    def cleanup
      indices = client.indices.get_aliases.
        select { |name, properties| properties.empty? || properties["aliases"].empty? }.
        select { |name, properties| name =~ /\A#{Regexp.escape(index_name)}_\d{14,17}\z/ }.keys

      indices.each do |index|
        Index.delete_index!(index: index)
        Rails.logger.info "ElasticProduct: Deleted index #{index}"
      end
    end

  end
end
