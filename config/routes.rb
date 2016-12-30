Spree::Core::Engine.routes.draw do
  namespace :admin do
    namespace :elastic_product do
      resource :settings, controller: '/solidus/elastic_product/admin/settings' do
        get :ping_service
      end

      resource :reindex, only: :create, controller: '/solidus/elastic_product/admin/reindex'
    end

    resources :products do
      resources :elastic_states, controller: '/solidus/elastic_product/admin/states', only: :show do
        put :reset, on: :member
      end
    end
  end
end
