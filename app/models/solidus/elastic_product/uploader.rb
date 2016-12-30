# Handles the upload of a batch of products (both index and delete operations)

module Solidus::ElasticProduct
  class Uploader
    attr_reader :response, :scope, :skipped

    def initialize product_ids
      @scope = State.where product_id: product_ids
      @skipped = []
      @response = nil
    end

    def execute
      @response = Index.client.bulk \
                   index:   Index.index_name,
                   type:    Index.document_type,
                   body:    generate_body

      process_results

      if succeeded?
        # Elastic says everything good. Mark it as uploaded so it won't be retried.
        @scope = @scope.where.not id: skipped unless skipped.empty?
        @scope.mark_uploaded!
      else
        # NOTE: We do not clear the lock on failure. This allows some time to
        # pass before we try again so hopefully the issue is cleared out.
        #
        # But we do still raise an error so the issue can be noticed (i.e. it
        # doesn't just silently keep retrying).
        raise Error, response
      end

      response
    end

  private

    def generate_body
      # It should only take seconds to generate the JSON
      Timeout::timeout 1.minute do
        index_scope = scope.indexable
        delete_scope = scope.not_indexable
        body = []

        index_scope.find_each do |state|
          # Just in case the json has been cleared since it was queued
          @skipped << state.id and next unless state.json?

          body.push({ index: { _id: state.id, data: state.json } } )
        end

        delete_scope.find_each do |state|
          body.push({ delete: { _id: state.id } })
        end

        body
      end
    end

    def succeeded?
      !response["errors"]
    end

    # An exception that can be used to communicate the problem
    class Error < StandardError
      # Automatically extract the relevant info and puts it into the error message.
      def initialize response
        super "Elastic failed for items: #{response['items']}}"
      end
    end

    def process_results
      if succeeded?
        Rails.logger.info "Elastic updated successfully in #{response['took']} ms"
      end
    end

  end
end
