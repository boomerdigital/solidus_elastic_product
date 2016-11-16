require 'spec_helper'

module Solidus::ElasticProduct
  describe SerializerJob do

    it 'will do nothing if incremental updating is disabled' do
      Config.incremental_update_enabled = false
      begin
        product = create :product
        subject.perform [product.id]
        expect( product.elastic_state.json ).to be nil
      ensure
        Config.incremental_update_enabled = true
      end
    end

    it 'will generate json and clear the lock on the given products' do
      product = create :product
      subject.perform [product.id]
      # If test fails this will generate exception as JSON will not be parsable
      JSON.parse product.elastic_state.reload.json
    end

  end
end
