Deface::Override.new(
  virtual_path:  'spree/admin/shared/sub_menu/_configuration',
  name:          'add_search_broker_admin_menu_link',
  insert_bottom: "[data-hook='admin_configurations_sidebar_menu']"
) do
  <<-HTML
    <%= configurations_sidebar_menu_item "Elastic Search Settings", spree.admin_elastic_product_settings_path %>
  HTML
end
