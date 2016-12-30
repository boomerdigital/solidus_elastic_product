module Solidus::ElasticProduct
  class UploaderJob < ActiveJob::Base
    queue_as :elastic_uploader

    def perform product_ids
      return unless Config.incremental_update_enabled

      Rails.logger.info "ElasticProduct: Uploading to Elastic.."

      # If Elastic is operating correctly we should have confirmation very quickly
      # (few seconds). But sometimes Elastic get's running behind so give them up
      # to 10.minutes
      Timeout::timeout 10.minute do
        Uploader.new(product_ids).execute
      end
    end

  end
end
