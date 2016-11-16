module Solidus::ElasticProduct
  module Admin
    class StatesController < Spree::Admin::BaseController
      before_action :find_product
      respond_to :html

      def show
        @elastic_state = @product.elastic_state
        @json = JSON.pretty_generate(JSON.parse(@elastic_state.json)) rescue nil
      end

      def reset
        state = @product.elastic_state
        state.reset!
        redirect_to admin_product_elastic_state_path(@product, state)
      end

      private

      def find_product
        @product = Spree::Product.friendly.find(params[:product_id])
      end

    end
  end
end
