require 'spec_helper'

module Solidus::ElasticProduct
  describe UploaderJob do
    let(:uploader) { instance_double(Uploader) }
    let(:product_ids) { [12, 13] }

    before do
      allow(Uploader).to receive(:new)
        .with(product_ids)
        .and_return(uploader)
    end

    it 'will call out to the uploader to upload the products' do
      expect(uploader).to receive(:execute)
      subject.perform product_ids
    end

    it 'will do nothing if incremental is not enabled' do
      Solidus::ElasticProduct::Config.incremental_update_enabled = false

      expect(uploader).not_to receive(:execute)

      begin
        subject.perform product_ids
      ensure
        Solidus::ElasticProduct::Config.incremental_update_enabled = true
      end
    end

  end
end
