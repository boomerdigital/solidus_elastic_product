require 'spec_helper'

module Solidus::ElasticProduct
  describe Uploader do

    describe 'successful upload' do
      let(:success_response) { {"errors" => false, "items" => []} }

      it 'will upload products with pre-generated JSON' do
        expected_args = {
          index: "products_test",
          type:  "spree/product",
          body:  [{:index=>{:_id=>1, :data=>'{"foo": "bar"}'}}]
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product = create :product_with_elastic_state, json: '{"foo": "bar"}'
        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq true
      end

      it 'will skip products without JSON' do
        expected_args = {
          index: "products_test",
          type:  "spree/product",
          body:  []
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product = create :product
        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq false
      end

      it 'will indicate what products should be removed' do
        expected_args = {
          index: "products_test",
          type:  "spree/product",
          body:  [{delete: {_id: 1}}]
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product = create :product
        product.destroy

        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq true
      end
    end

    describe 'unsuccessful upload' do
      let(:error_response)   { {"errors" => true, "items" => []} }

      it 'will raise an error if uploader was not successful' do
        expect(Index.client).to receive(:bulk).and_return(error_response)

        product = create :product_with_elastic_state, json: '{"foo": "bar"}'
        subject = described_class.new([product.id])

        expect { subject.execute }.to raise_error described_class::Error
        expect( product.elastic_state.reload.uploaded? ).to eq false
      end
    end
  end
end
