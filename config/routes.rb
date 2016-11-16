Spree::Core::Engine.routes.draw do
  namespace :admin do
    resource :elastic_product_settings, controller: '/solidus/elastic_product/admin/settings' do
      get :ping_my_service
    end

    resources :products do
      resources :elastic_states, controller: '/solidus/elastic_product/admin/states', only: :show do
        put :reset, on: :member
      end
    end
  end
end
