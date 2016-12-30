require 'spec_helper'

describe 'Elastic Product Settings' do
  stub_authorization!

  describe '#update settings' do
    before do
      Solidus::ElasticProduct::Config.incremental_update_enabled = true
    end

    after do
      Solidus::ElasticProduct::Config.incremental_update_enabled = true
    end

    it 'allows to change the incremental_update_enabled flag' do
      visit spree.edit_admin_general_settings_path
      click_link 'Elastic Search'

      expect(page).to have_field 'Incremental Update Enabled', checked: true

      uncheck "Incremental Update Enabled"
      click_button 'Update'
      expect(page).to have_field 'Incremental Update Enabled', checked: false
    end
  end

  describe 'Full reindex' do
    it 'allows to start a background job to perform a full reindex' do
      visit spree.admin_elastic_product_settings_path

      expect(Solidus::ElasticProduct::ReindexJob).to receive(:perform_later)
      click_button 'Start full reindex'
    end
  end

end
