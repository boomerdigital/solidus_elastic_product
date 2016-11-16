class CreateElasticProductState < ActiveRecord::Migration
  def up
    create_table :solidus_elastic_product_states do |t|
      t.belongs_to :product, null: false, index: true, unique: true
      t.text :json, limit: (16.megabytes - 1)
      t.boolean :uploaded, default: false, null: false
      t.datetime :locked_for_serialization_at, :locked_for_upload_at

      t.index [:json, :locked_for_serialization_at], name: 'serialization_lookup', length: { json: 1 }
      t.index [:uploaded, :locked_for_upload_at, :json], name: 'upload_lookup', length: { json: 1 }
    end
    execute "INSERT INTO #{Solidus::ElasticProduct::State.table_name} (product_id) SELECT id FROM #{Spree::Product.table_name}"
  end

  def down
    drop_table :solidus_elastic_product_states
  end
end
