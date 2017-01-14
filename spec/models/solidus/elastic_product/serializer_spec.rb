require 'spec_helper'

module Solidus::ElasticProduct
  describe Serializer do

    # This is a fairly complicated test that covers a lot of code in the model.
    # but all that code is really internal. The only exposed things we are
    # concered with are:
    #
    # * The correct JSON is generated
    # * When loading via the SerializationIterator refinement it also works
    #
    # Everything else is an implementation detail not relevant to black-box testing
    describe '#generate_indexed_json' do
      let(:stock_location) { create :stock_location }
      let(:option_type) { create :option_type, name: 'condition' }
      let(:image) { build :image }
      let(:variant_image) { build :image } # should pick the master image instead
      let(:master) { build :master_variant, sku: '4949593040589', price: 2.99, images: [image] }
      let(:variant_1) do
        build :variant, sku: 'U4949593040589', price: 1, images: [variant_image],
          option_values: [build(:option_value, name: 'used', option_type: option_type)]
      end
      let(:variant_2) do
        build :variant, sku: 'V4949593040589', price: 2.99,
          option_values: [build(:option_value, name: 'new', option_type: option_type)]
      end
      let(:taxonomy) { create :taxonomy, name: 'Genre' }
      let(:taxon) {
        build :taxon, name: 'Rock', taxonomy: taxonomy,
          parent: taxonomy.root,
          description: "Main Taxon Descr",
          meta_description: "Meta Desc",
          meta_title: "Meta Titl"
      }
      let(:sub_taxon) {
        build :taxon, name: 'Roll', taxonomy: taxonomy,
          parent: taxon
      }
      let(:property) { build :product_property, value: 'Pixies', property: build(:property, name: 'artist') }
      let(:line_item_with_master_variant) { create :line_item, variant: master }
      let(:line_item_with_regular_variant) { create :line_item, variant: variant_1 }
      let :product do
        create :product, name: 'my name', description: 'my description',
          created_at: Date.parse('2017-01-12'),
          master: master,
          variants: [variant_1, variant_2],
          product_properties: [property],
          taxons: [sub_taxon],
          option_types: [option_type]
      end

      # let(:subject) { described_class.new(product) }

      let :expected do
        <<JSON
{
  "id": #{product.id},
  "name": "my name",
  "description": "my description",
  "slug": "my-name",
  "created_at": "2017-01-12T00:00:00Z",
  "popularity": 2,
  "image": {
    "small_url": "#{image.attachment.url(:small)}"
  },
  "master": {
    "id": #{master.id},
    "sku": "4949593040589",
    "price": "2.99",
    "display_price": "$2.99",
    "total_on_hand": 0,
    "option_values": [

    ]
  },
  "variants": [
    {
      "id": #{variant_1.id},
      "sku": "U4949593040589",
      "price": "1.00",
      "display_price": "$1.00",
      "total_on_hand": 5,
      "option_values": [
        {
          "name": "used",
          "option_type_name": "condition"
        }
      ]
    },
    {
      "id": #{variant_2.id},
      "sku": "V4949593040589",
      "price": "2.99",
      "display_price": "$2.99",
      "total_on_hand": 8,
      "option_values": [
        {
          "name": "new",
          "option_type_name": "condition"
        }
      ]
    }
  ],
  "properties": [
    {
      "value": "Pixies",
      "property_name": "artist"
    }
  ],
  "taxons": [
    {
      "name": "Genre",
      "permalink": "genre",
      "description": null,
      "permaname": "genre||Genre",
      "child": {
        "name": "Rock",
        "permalink": "genre/rock",
        "description": "Main Taxon Descr",
        "permaname": "genre/rock||Rock",
        "child": {
          "name": "Roll",
          "permalink": "genre/rock/roll",
          "description": null,
          "permaname": "genre/rock/roll||Roll"
        }
      }
    }
  ]
}
JSON
      end

      before do
        product and expected
        variant_1.stock_items.first.set_count_on_hand 5
        variant_2.stock_items.first.set_count_on_hand 8
        line_item_with_master_variant and line_item_with_regular_variant
      end

      it 'can generate via a simple call' do
        json = described_class.new(product).generate_indexed_json
        expect( JSON.pretty_generate JSON.parse(json) ).to eq expected.strip
      end

      using Config.serializer_class::SerializationIterator

      it 'can generate with loaded data via iterator refinement' do
        Spree::Product.where(id: product.id).each_for_serialization do |product|
          # If the preloading works right there should be 0 SQL queries
          expect do
            json = described_class.new(product).generate_indexed_json
            expect( JSON.pretty_generate JSON.parse(json) ).to eq expected.strip
          end.to change(SqlCounter, :count).by(0)
        end
      end

      it 'is uses fresh taxons (not stale cached versions)' do
        Spree::Product.where(id: product.id).each_for_serialization do |product|
          json = described_class.new(product).generate_indexed_json
        end

        new_taxon = create(:taxon, parent: taxonomy.root, taxonomy: taxonomy)
        product.taxons << new_taxon

        Spree::Product.where(id: product.id).each_for_serialization do |product|
          json = described_class.new(product).generate_indexed_json
          json = JSON.parse(json)

          expect( json["taxons"].size).to eq 2
          json["taxons"].each do |taxon_node|
            expect(taxon_node["child"]).not_to be_empty
          end
        end
      end
    end

  end
end
