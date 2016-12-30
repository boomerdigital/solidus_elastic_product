Deface::Override.new(
  virtual_path:  'spree/admin/shared/_settings_sub_menu',
  name:          'add_search_broker_admin_menu_link',
  insert_bottom: "[data-hook='admin_settings_sub_tabs']"
) do
  <<-HTML
    <% if can?(:edit, :general_settings) %>
      <%= tab :elastic_product_settings, url: spree.admin_elastic_product_settings_path %>
    <% end %>
  HTML
end
