module Solidus::ElasticProduct
  module Admin
    class SettingsController < Spree::Admin::BaseController
      respond_to :html

      def show
      end

      def ping_my_service
        result = Solidus::ElasticProduct::Index.client.ping

        if result == "{}"
          flash[:success] = "Ping Successful"
        else
          flash[:error] = "Ping Error"
        end

        respond_to do |format|
          format.js
        end
      end

      def update
        settings = params[:settings] || {}
        Solidus::ElasticProduct::Config.incremental_update_enabled = settings[:incremental_update_enabled] == '1'
        respond_to do |format|
          format.html {
            redirect_to admin_elastic_search_settings_path
          }
        end
      end
    end
  end
end
