Deface::Override.new(
  virtual_path:  'spree/admin/shared/_product_tabs',
  name:          'add_elastic_state_admin_menu_link',
  insert_bottom: "[data-hook='admin_product_tabs']"
) do
  <<-HTML
  <%= content_tag :li, class: ('active' if current == :elastic_state) do %>
   <%= link_to_with_icon 'search', 'Elastic State', spree.admin_product_elastic_state_path(@product, @product.elastic_state) %>
  <% end if can?(:admin, Spree::Product) %>
  HTML
end
