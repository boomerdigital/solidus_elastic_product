# Right now I just have a `create` action to create a new job. But possibly
# later we might implement a `show` action to view the status or delete to
# cancel an existing job.
module Solidus::ElasticProduct
  module Admin
    class ReindexController < Spree::Admin::BaseController
      # Kick off a new update.
      def create
        ReindexJob.perform_later
        flash[:success] = 'Background search index update initiated'
        redirect_to spree.admin_elastic_product_settings_path
      end
    end
  end
end

