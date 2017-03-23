class CreateElasticProductState < ActiveRecord::Migration
  def up
    create_table :solidus_elastic_product_states do |t|
      t.belongs_to :product, null: false, index: true, unique: true
      t.text :json, limit: (16.megabytes - 1)
      t.boolean :uploaded, default: false, null: false, index: true
      t.datetime :locked_for_serialization_at
      t.datetime :locked_for_upload_at, index: true

      t.index :locked_for_serialization_at, name: 'index_states_on_locked_for_serialization_at'

      # Partial index for Postgres only
      if connection.adapter_name =~ /postgres/i
        t.index :json, where: 'json is null'
      end
    end

    # Run Insert outside of a transaction for Postgres
    if connection.adapter_name =~ /postgres/i
      execute("commit;")
    end

    execute "INSERT INTO #{Solidus::ElasticProduct::State.table_name} (product_id) SELECT id FROM #{Spree::Product.table_name}"
  end

  def down
    drop_table :solidus_elastic_product_states
  end
end
