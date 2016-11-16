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
      let(:master) { build :master_variant, sku: '4949593040589', price: 2.99, images: [image] }
      let(:variant_1) do
        build :variant, sku: 'U4949593040589', price: 1,
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
      let(:property) { build :product_property, value: 'Pixies', property: build(:property, name: 'artist') }
      let :product do
        create :product, name: 'my name', description: 'my description',
          master: master,
          variants: [variant_1, variant_2],
          product_properties: [property],
          taxons: [taxon],
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
  "shipping_category_id": #{Spree::ShippingCategory.first.id},
  "master": {
    "id": #{master.id},
    "sku": "4949593040589",
    "price": "2.99",
    "display_price": "£2.99",
    "in_stock": false,
    "total_on_hand": 0,
    "backorderable": true,
    "option_values": [

    ],
    "images": [
      {
        "position": 1,
        "small_url": "#{image.attachment.url :small}"
      }
    ]
  },
  "variants": [
    {
      "id": #{variant_1.id},
      "sku": "U4949593040589",
      "price": "1.00",
      "display_price": "£1.00",
      "in_stock": true,
      "total_on_hand": 5,
      "backorderable": false,
      "option_values": [
        {
          "name": "used",
          "option_type_name": "condition"
        }
      ],
      "images": [

      ]
    },
    {
      "id": #{variant_2.id},
      "sku": "V4949593040589",
      "price": "2.99",
      "display_price": "£2.99",
      "in_stock": true,
      "total_on_hand": 8,
      "backorderable": true,
      "option_values": [
        {
          "name": "new",
          "option_type_name": "condition"
        }
      ],
      "images": [

      ]
    }
  ],
  "product_properties": [
    {
      "value": "Pixies",
      "property_name": "artist"
    }
  ],
  "classifications": [
    {
      "taxon": {
        "id": #{taxon.id},
        "name": "Rock",
        "parent_id": #{taxon.parent_id},
        "permalink": "genre/rock",
        "description": "Main Taxon Descr",
        "meta_description": "Meta Desc",
        "meta_title": "Meta Titl",
        "taxons": [
          {
            "id": #{taxon.parent_id},
            "name": "Genre",
            "parent_id": null,
            "permalink": "genre",
            "description": null,
            "meta_description": null,
            "meta_title": null
          }
        ]
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
        variant_1.stock_items.first.update_column(:backorderable, false)
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

          expect( json["classifications"].size).to eq 2
          json["classifications"].each do |taxon_node|
            expect(taxon_node["taxon"]["taxons"]).not_to be_empty
          end
        end
      end
    end

  end
end
