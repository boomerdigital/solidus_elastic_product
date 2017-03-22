require 'spec_helper'

module Solidus::ElasticProduct
  describe Uploader do

    describe 'successful upload' do
      let(:success_response) { {"errors" => false, "items" => []} }

      it 'will upload products with pre-generated JSON' do
        product = create :product_with_elastic_state, json: '{"foo": "bar"}'

        expected_args = {
          index: "products_test",
          type:  "product",
          body:  [{:index=>{:_id=> product.elastic_state.id, :data => '{"foo": "bar"}'}}]
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq true
      end

      it 'will skip products without JSON' do
        expected_args = {
          index: "products_test",
          type:  "product",
          body:  []
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product = create :product
        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq false
      end

      it 'will skip already uploaded products' do
        expected_args = {
          index: "products_test",
          type:  "product",
          body:  []
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product = create :product
        product = create :product_with_elastic_state, json: '{"foo": "bar"}', uploaded: true
        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq true
      end

      it 'will indicate what products should be removed' do
        product = create :product

        expected_args = {
          index: "products_test",
          type:  "product",
          body:  [{delete: {_id: product.elastic_state.id}}]
        }
        expect(Index.client).to receive(:bulk).with(expected_args).and_return(success_response)

        product.destroy

        subject = described_class.new([product.id])
        subject.execute

        expect( product.elastic_state.reload.uploaded? ).to eq true
      end
    end

    describe 'unsuccessful upload' do
      let(:product) { create :product_with_elastic_state, json: '{"foo": "bar"}' }

      let(:error_response) {
        {
          "errors" => true,
          "items" => [
            "index" => {
                "_index" => "products_development_20170204141456055",
                 "_type" => "product",
                   "_id" => product.elastic_state.id,
                "status" => 400,
                 "error" => {
                          "type" => "routing_missing_exception",
                        "reason" => "routing is required for [products_development_20170204141456055]/[product]/[173802]",
                    "index_uuid" => "_na_",
                         "index" => "products_development_20170204141456055"
                }
            }
          ]
        }
      }

      it 'will raise an error if uploader was not successful' do
        expect(Index.client).to receive(:bulk).and_return(error_response)

        subject = described_class.new([product.id])

        expect { subject.execute }.to raise_error described_class::Error, /routing is required/
        expect( product.elastic_state.reload.uploaded? ).to eq false
      end
    end
  end
end
