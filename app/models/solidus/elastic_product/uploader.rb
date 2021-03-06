# Handles the upload of a batch of products (both index and delete operations)

module Solidus::ElasticProduct
  class Uploader
    attr_reader :response, :scope, :skipped

    def initialize product_ids
      @scope = State.where uploaded: false, product_id: product_ids
      @skipped = []
      @failures = []
      @response = nil
    end

    def execute
      body = generate_body
      return if body.empty?

      @response = Index.client.bulk \
                   index:   Index.index_name,
                   type:    Index.document_type,
                   body:    body

      process_results

      @skipped += @failures.select { |item| item['index'] }.map { |item| item['index']['_id'] }
      @skipped += @failures.select { |item| item['delete'] }.map { |item| item['delete']['_id'] }

      # Mark successes as uploaded
      @scope = @scope.where.not id: @skipped unless @skipped.empty?
      @scope.mark_uploaded!

      if @failures.any?
        # NOTE: We do not clear the lock on failure. This allows some time to
        # pass before we try again so hopefully the issue is cleared out.
        #
        # But we do still raise an error so the issue can be noticed (i.e. it
        # doesn't just silently keep retrying).
        raise Error, @failures
      end

      @response
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

          body.push(Index.__transform.call(state))
        end

        delete_scope.find_each do |state|
          body.push(Index.transform_delete.call(state))
        end

        body
      end
    end

    # An exception that can be used to communicate the problem
    class Error < StandardError
      # Automatically extract the relevant info and puts it into the error message.
      def initialize failed
        super "failed items: " << failed.to_s
      end
    end

    def process_results
      @failures = @response['items'].select do |item|
        (item['index'] && item['index'].key?('error')) || (item['delete'] && item['delete'].key?('error'))
      end

      total = @scope.count
      Rails.logger.info "elastic-product: updated #{total - @failures.size} out of #{total} in #{@response['took']} ms"
    end

  end
end
