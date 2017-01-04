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

          preload = -> (object, method, value) { object.singleton_class.send(:define_method, method) { value } }

          scope = includes :elastic_state, :taxons, product_properties: :property,
            variants: [{ option_values: :option_type }, :default_price],
            master: [:default_price, :images]

          records = scope.to_a # Load outside of transaction to prevent excessive locking
          State.transaction do
            records.each do |product|
              preload[product, :total_on_hand, products_on_hand[product.id] || 0]
              preload[product.master, :total_on_hand, variants_on_hand[product.master.id] || 0]

              for variant in product.variants
                preload[variant, :total_on_hand, variants_on_hand[variant.id] || 0]
              end

              for taxon in product.taxons
                preload[taxon, :ancestors, Spree::Taxon.ancestors_for(taxon)]
              end

              blk.call product
            end
          end
        end
      end

      refine Spree::Taxon.singleton_class do
        # The exact same as taxon.ancestors only all the taxons and determined once
        # and cached. After that it is just a lookup.
        def ancestors_for requested_taxon
          @ancestors_by_taxon ||= begin
            all.inject(Hash.new {|h, k| h[k] = []}) do |hsh, taxon|
              taxon_id = taxon.id
              begin
                parent = by_id[taxon.parent_id]
                hsh[taxon_id] << parent if parent
              end until (taxon = parent).nil?
              hsh
            end
          end

          @ancestors_by_taxon[requested_taxon.id].sort_by &:id
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

    private

    # A refinement that augments the core spree models so they know how to
    # generate their portion of the search broker representation. That
    # representation is then given to the JSON encoder to generate the final JSON.
    module ElasticRepresentation
      refine Spree::Product do
        def as_indexed_hash
          {
            id: id, name: name, description: description, slug: slug,
            shipping_category_id: shipping_category_id, master: master.as_indexed_hash,
            variants: variants.collect {|v| v.as_indexed_hash},
            product_properties: product_properties.collect {|p| p.as_indexed_hash},
            classifications: classifications.collect {|c| {taxon: c.taxon.as_indexed_hash}}
          }
        end
      end

      refine Spree::Variant do
        def as_indexed_hash
          money = default_price.display_price
          {
            id: id, sku: sku, price: money.money.format(symbol: false),
            display_price: money.to_s,
            total_on_hand: total_on_hand
          }.tap do |ret|
            if is_master?
              ret[:option_values] = []
              ret[:images] = images.collect {|i| i.as_indexed_hash}
            else
              ret[:option_values] = option_values.collect {|o| o.as_indexed_hash}
              ret[:images] = []
            end
          end
        end
      end

      refine Spree::ProductProperty do
        def as_indexed_hash
          {value: value, property_name: property_name}
        end
      end

      refine Spree::Taxon do
        def as_indexed_hash ancestor: false
          {
            id: id, name: name, parent_id: parent_id, permalink: permalink,
            description: description,
            meta_description: meta_description,
            meta_title: meta_title,
            ancestors: [self_and_ancestors.collect { |t| t.attributes }]
          }
        end
      end

      refine Spree::Image do
        def as_indexed_hash
          { position: position, small_url: attachment.url(:small) }
        end
      end

      refine Spree::OptionValue do
        def as_indexed_hash
          { name: name, option_type_name: option_type_name }
        end
      end
    end

    using ElasticRepresentation

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
    public :generate_indexed_json

  end
end
