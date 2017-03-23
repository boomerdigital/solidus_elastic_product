# Extends the product to manage the serialization to elastic

module Solidus::ElasticProduct
  class Serializer
    attr_reader :product

    def initialize(product)
      @product = product
    end

    # A refinement that helps you iterate on a batch of products to be seriaized.
    # While you could just call the `generate_json` method on each state record
    # it would be very slow on a lot of records because of how the records are
    # loaded. Use this refinement to gain a method for efficiently loading a
    # batch of records that you can then call `generate_json` with all the data
    # pre-loaded.
    module SerializationIterator
      # NOTE: ActiveRecord::Relation is refined but is really only for the
      # purpose of iterating Spree::Product relations. Luckily refinments keeps
      # this overreach at bay.
      refine ActiveRecord::Relation do
        # Operates the same as `each` only:
        #
        # * It operates in batches so if a lot of products need to be uploaded
        #   we uses constant memory.
        # * Each batch operates in a transaction so the serialization is faster
        # * Complicated queries are pre-loaded and monkey-patched into avoid
        #   N+1 loading.
        # * Related data needed by the SB upload are pre-loaded to avoid N+1 loading
        def each_for_serialization &blk
          Spree::Taxon.reset_cache!

          sub_query = select('id').to_sql

          # Pre-load and monkey-patch data in during loop since it's a non-standard
          # type of preloading
          stock_scope = Spree::StockItem.
            joins(:variant).references(:variant).
            where "product_id IN (#{sub_query})"
          products_on_hand = stock_scope.group(:product_id).sum :count_on_hand
          variants_on_hand = stock_scope.
            joins(:stock_location).references(:stock_location).
            where(spree_stock_locations: {active: true}).
            group(:variant_id).sum :count_on_hand

          # With postgres, we can grab just the first image per product, saving on memory.
          # The order bit takes care to select the master images if any first.
          distinct = ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' ? 'distinct on (product_id) ' : ''
          images = Spree::Image.
            select(distinct + 'spree_variants.product_id, spree_assets.*').
            joins("join spree_variants on viewable_id = spree_variants.id").
            order("spree_variants.product_id", :position, "spree_variants.position", "spree_variants.id").
            where("spree_variants.product_id in (#{sub_query})").
            group_by &:product_id

          popularity = Spree::LineItem.
            joins(:variant).
            where("product_id IN (#{sub_query})").
            group(:product_id).count

          # Very rought implementation
          prices = Spree::Price.
            joins(:variant).
            where("spree_variants.product_id in (#{sub_query})").
            group("spree_variants.product_id").
            minimum(:amount)

          preload = -> (object, method, value) { object.singleton_class.send(:define_method, method) { value } }

          scope = includes :elastic_state, :indexable_classifications, :master,
            indexable_product_properties: :property,
            variants: [{ option_values: :option_type }]

          records = scope.to_a # Load outside of transaction to prevent excessive locking
          State.transaction do
            records.each do |product|
              preload[product, :total_on_hand, products_on_hand[product.id] || 0]
              preload[product.master, :total_on_hand, variants_on_hand[product.master.id] || 0]

              for variant in product.variants
                preload[variant, :total_on_hand, variants_on_hand[variant.id] || 0]
              end

              preload[product, :display_image, images.key?(product.id) && images[product.id][0] || Spree::Image.new]

              preload[product, :indexed_popularity, popularity[product.id] || 0]

              preload[product, :indexed_price, prices[product.id] || 0]

              for classification in product.indexable_classifications
                taxon = Spree::Taxon.by_id[classification.taxon_id]
                preload[classification, :taxon, taxon]
                preload[taxon, :self_and_ancestors, Spree::Taxon.self_and_ancestors(taxon)]
              end

              blk.call product
            end
          end
        end
      end

      refine Spree::Taxon.singleton_class do
        # The exact same as taxon.ancestors only all the taxons and determined once
        # and cached. After that it is just a lookup.
        def self_and_ancestors requested_taxon
          @ancestors_by_taxon ||= begin
            all.inject({}) do |hsh, taxon|
              taxon_id = taxon.id
              hsh[taxon_id] = [taxon]
              begin
                parent = by_id[taxon.parent_id]
                hsh[taxon_id] << parent if parent
              end until (taxon = parent).nil?
              hsh[taxon_id]
              hsh
            end
          end

          @ancestors_by_taxon[requested_taxon.id].reverse
        end

        # Returns and caches all taxons indexed by parent id
        def by_id
          @by_id ||= all.index_by &:id
        end

        def reset_cache!
          max_updated_at = Spree::Taxon.maximum(:updated_at)
          if max_updated_at != @cached_at
            @cached_at = max_updated_at
            @by_id = nil
            @ancestors_by_taxon = nil
          end
        end
      end
    end

    # A module that augments the core spree models so they know how to
    # generate their portion of the elastic representation. That
    # representation is then given to the JSON encoder to generate the final JSON.

    # To override the default representation, copy the method over to your
    # decorated class and modify as needed.
    module ElasticRepresentation
      Spree::Product.class_eval do
        def as_indexed_hash
          displayed_price = Spree::Money.new(indexed_price) # single currency support only
          {
            id: id, name: name, description: description, slug: slug,
            created_at: created_at.to_formatted_s(:iso8601),
            popularity: indexed_popularity,
            image: display_image.as_indexed_hash,
            price: displayed_price.money.format(symbol: false),
            display_price: displayed_price.to_s,
            master: master.as_indexed_hash,
            variants: variants.collect {|v| v.as_indexed_hash}.compact,
            properties: indexable_product_properties.collect {|p| p.as_indexed_hash},
            taxons: indexable_classifications.collect {|c| c.as_indexed_hash}
          }
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::Variant.class_eval do
        def as_indexed_hash
          {
            id: id, sku: sku,
            total_on_hand: total_on_hand
          }.tap do |ret|
            if is_master?
              ret[:option_values] = []
            else
              ret[:option_values] = option_values.collect {|o| o.as_indexed_hash}
            end
          end
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::ProductProperty.class_eval do
        def as_indexed_hash
          {value: value, property_name: property_name}
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::Classification.class_eval do
        def as_indexed_hash
          taxon.self_and_ancestors.inject({}) do |as_hash, taxon|
            next taxon.as_indexed_hash if as_hash.blank?

            current = as_hash
            current = current[:child] while current[:child]
            current[:child] = taxon.as_indexed_hash

            as_hash
          end
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::Taxon.class_eval do
        def as_indexed_hash
          {
            name: name,
            lft: lft,
            permalink: permalink,
            description: description,
            permaname: [permalink, '||', name].join
          }
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::Image.class_eval do
        def as_indexed_hash
          { url: attachment.url(:small) }
        end unless instance_methods(true).include?(:as_indexed_hash)
      end

      Spree::OptionValue.class_eval do
        def as_indexed_hash
          { name: name, option_type_name: option_type_name }
        end unless instance_methods(true).include?(:as_indexed_hash)
      end
    end

    include ElasticRepresentation

    # Returns the JSON representation of a Product
    #
    # NOTE: This MUST be defined after the refinement is defined
    # and using because of the way that refinements work.
    #
    # @return [json] any string will do. It will be stored
    #   in the `json` column in the State table.

    def generate_indexed_json
      product.as_indexed_hash.to_json
    end

  end
end
