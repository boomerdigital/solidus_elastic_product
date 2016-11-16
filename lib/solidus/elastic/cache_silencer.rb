module Solidus::ElasticProduct
  module CacheSilencer

    # This prevents Rails's cache from being effective. Shouldn't generally be
    # used but if you know your operation will not use cached data this can save
    # time and disk space (if the cache is filesystem based).
    def silence_cache
      old_cache, Rails.cache = Rails.cache, ActiveSupport::Cache::NullStore.new
      yield
    ensure
      Rails.cache = old_cache
    end

  end
end
