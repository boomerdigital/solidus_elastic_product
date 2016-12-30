module Solidus::ElasticProduct
  module Admin
    class SettingsController < Spree::Admin::BaseController
      respond_to :html

      def show
      end

      def update
        settings = params[:settings] || {}
        Solidus::ElasticProduct::Config.incremental_update_enabled = settings[:incremental_update_enabled] == '1'
        respond_to do |format|
          format.html {
            redirect_to admin_elastic_product_settings_path
          }
        end
      end

      def ping_service
        if Solidus::ElasticProduct::Index.client.ping
          flash[:success] = "Ping successful!"
        else
          flash[:error] = "Ping errored"
        end
      end

    end
  end
end
