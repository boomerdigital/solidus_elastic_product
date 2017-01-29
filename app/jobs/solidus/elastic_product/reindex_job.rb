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
              :create_index!, to: Index

    def perform
      old_state = Config.incremental_update_enabled
      Config.incremental_update_enabled = false

      # Create a brand new index
      new_index_name = index_name + "_" + Time.now.strftime('%Y%m%d%H%M%S%L')
      create_index!(index: new_index_name)

      # And upload all to it
      errored = []

      Index.import(index: new_index_name, batch_size: 500) do |response|
        report_on(response)

        # Collect errored products
        response['items'].select { |item| item['index'].key?('error') }.
                          each   { |item| errored << item['index']['_id'] }
      end

      Rails.logger.info "elastic-product: Errors on reindex: " << errored.size.to_s

      total = State.count
      if total > 0 && errored.size.to_f / total > 0.05
        Rails.logger.error "elastic-product: More than 5% errors. Aborting index swap."
        return
      end

      # Switch to use the newly created index for search
      swap(new_index_name)

      # If all good up till here, mark all those successfully
      # indexed products as uploaded
      State.where.not(id: errored).mark_uploaded!

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
        response['items'].select { |item| item.key?('error') }.each do |item|
          Rails.logger.error "elastic-product: Failed to index: " << item.to_s
        end
      else
        Rails.logger.info "elastic-product: Reindexed batch successfully in #{response['took']} ms"
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
        Rails.logger.info "elastic-product: Deleted index #{index}"
      end
    end

  end
end
