require 'spec_helper'

describe 'Elastic State' do
  stub_authorization!

  let(:product) { create :product_with_elastic_state, json: '{ "foo": "bar" }', uploaded: true }

  # As the views are only complementary, disable the tests
  # The extension works well with Solidus 1.2 and probably below
  before do
    skip if Gem.loaded_specs['solidus'].version < Gem::Version.new("1.4")
  end

  describe '#show' do
    it 'displays the search broker state tab' do
      visit spree.admin_product_path product
      expect(page).to have_content('Elastic State')
    end
  end

  describe '#update' do
    it 'resets the search broker state' do
      visit spree.admin_product_path product

      click_link 'Elastic State'
      expect(page).to have_content('Uploaded?: true')
      expect(page).to have_content('{ "foo": "bar" }')

      click_button 'Reset'
      expect(page).to have_content('Uploaded?: false')
      expect(page).not_to have_content('{ "foo": "bar" }')
    end
  end

end
