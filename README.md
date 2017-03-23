Solidus Elastic Product
-----------------------

[![Build Status](https://travis-ci.org/boomerdigital/solidus_elastic_product.svg?branch=master)](https://travis-ci.org/boomerdigital/solidus_elastic_product)


This integration for Elastic Search provides a performance way to index products for Solidus ecommerce stores. To achieve that, products are concurrently serialized & uploaded with background jobs in batches.

The gem is used in production at:

  - [Tee Shirt Palace](https://www.teeshirtpalace.com/products) with Solidus 1.2


Serialization of 500 products takes ~ _20 seconds_. Already serialized 200K products can be uploaded to Elastic in ~ _10 mins_.


The integration focuses on the backend synchronization of products with Elastic Search, and as such, does not have any frontend views, and does not construct any frontend search queries.

It has a dependency on the official [Elasticsearch Model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model) library and exposes its full interface through the `Index` and `State` classes.


### Background

Existing integrations for indexing data to Elastic Search perform the serialization and upload operations on the fly, which does not allow for any optimizations to be added. Instead, by adding an intermediate storage for the serialized data, and separating the _serialization_ and _upload_ operations, we get to:

- pre-load the data for serialization, thereby reducing sql lookups, avoiding N+1 query problem

- upload batches of products to Elastic Search, reducing network trips and number of index operations performed by Elastic

- inspect the serialized data with ease, as well as display it in an admin user interface

- serialize and upload in parallel

- do a full indexation of all products within minutes (~ 10 mins per 200K products) - which is useful in two situations:

  1. Change of elastic mappings
  2. Recover from cluster failure (this eliminates the need to pay for redundant search clusters)

- perform inline update of the generated json data if only a single property is changed (such as _view_count_) avoiding full-reserialization of the product



### Installation and quick start

Add solidus_elastic_product to your Gemfile:

```ruby
gem 'solidus_elastic_product'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rake railties:install:migrations
bundle exec rake db:migrate
```

Serialize all products for the first time

```ruby
Solidus::ElasticProduct::Schedule.serialize_all

# monitor the serialized products or just tail the logs
Solidus::ElasticProduct::State.needing_upload.count

# once serialized (or can stop midway if testing), upload them all to elastic
Solidus::ElasticProduct::ReindexJob.perform_now
```


### To connect to Elastic Search

Cleanest is really to place an `ELASTICSEARCH_URL` environmental variable, for example in `.env`. No such is necessary for _localhost_.


### Workflow

To work with an intermediate storage of the serialized data, the following workflow has been set up:

1. A corresponding one-to-one record in a `Elastic::Product::State` table is created for every product. It is used to store the state of an _indexed_ product and consists of the following fields:

  ```ruby
  {
                               :id => nil,
                       :product_id => nil,
                             :json => nil,
                         :uploaded => false,
      :locked_for_serialization_at => nil,
             :locked_for_upload_at => nil
  }
  ```

  Fields:

  - `json` - string representation of a serialized product;
  - `uploaded` - boolean flag to indicate if the product has been synced with Elastic
  - `locked_for_serialization_at` - time when a worker has started processing the product for serialization
  - `locked_for_upload_at` - time when a worker has started uploading the product for Elastic Search

  The two `locked` columns ensure that concurrent serialization and upload processes do not overlap each other.


2. To serialize products:

  - [`Solidus::ElasticProduct::SerializerJob.perform_now([product_id_1, product_id_2 ..])`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/jobs/solidus/elastic_product/serializer_job.rb#10)  - serializes just the product ids specified as arguments in an array.

  - [`Solidus::ElasticProduct::Schedule.serialize_all`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/schedule.rb#L27) - splits all products in batches of 500, and creates a `SerializerJob` for each such batch.

  - run [`Solidus::ElasticProduct.monitor`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/schedule.rb#L15) as a clock process - it will check for products that need to be serialized (the `json` field in the State table is `nil`) every minute. If it finds such, it splits them in batches of 500 and creates `SerializerJob`s.

    Usually, an _upstart_ job or so is set-up to auto-start and deamonize this clock process.


3. To upload products to Elastic:

  - [`Solidus::ElasticProduct::ReindexJob.perform_now`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/jobs/solidus/elastic_product/reindex_job.rb#L15) - will create a new index in elastic search, upload all _serialized_ products to this new index, [swap](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/jobs/solidus/elastic_product/reindex_job.rb#L62) the _alias_ for the environment (development, production) to the new index, and delete any old indices for the same environment.

    This one is to be used when starting out, mappings are changed, or just want to start anew with a fresh index.


  - [`Solidus::ElasticProduct::UploaderJob.perform_now([product_id_1, product_id_2 ..])`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/jobs/solidus/elastic_product/uploader_job.rb)  - uploads just the product ids specified as arguments in an array.


  - run [`Solidus::ElasticProduct.monitor`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/schedule.rb#L15) as a clock process - will check every minute for already serialized product _states_ that need to be uploaded, and will create `UploaderJob`s to handle the upload



### To operate through Elastic Model

 - Use the `Solidus::ElasticProduct::Index` class to perform class operations (define index name, do mappings, perform search or manipulate the index)

 - Use the `Solidus::ElasticProduct::State` class to perform instance level operations with individual indexed products (update, destroy, etc..)



### To configure Elastic Search settings and mappings

All of [Elastic Search Model](https://github.com/elastic/elasticsearch-rails/tree/master/elasticsearch-model's) class methods are available through the `Index` class. So, you can directly customize them from an initializer:

```ruby
# config/initializers/elastic_product.rb
Solidus::ElasticProduct::Index.index_name
Solidus::ElasticProduct::Index.document_type
Solidus::ElasticProduct::Index.mapping
```

For example, to change the [default Elastic Search mappings](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/index.rb#L52), in an initializer (or Index decorator) do:

```ruby
# config/initializers/elastic_product.rb
options = { ... }

Solidus::ElasticProduct::Index.mappings(options) do
  indexes :name,          type: 'string', analyzer: 'snowball'
  indexes :created_at,    type: 'date'
  indexes :taxons,        type: 'nested' do
    indexes :permaname,   type: 'keyword', index: 'not_analyzed'
    indexes :child do
      indexes :permaname, type: 'keyword', index: 'not_analyzed'
      indexes :child do
        indexes :permaname, type: 'keyword', index: 'not_analyzed'
      end
    end
  end
end
```


### To customize the serialization

1. Change the default [indexed product hash](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/serializer.rb#L147)

  Just define a `as_indexed_hash` method in your Spree `product_decorator`. Your method will then take precedence. Ex:

  ```ruby
  def as_indexed_hash
    {
      name: name,
      popularity: indexed_popularity,
      view_count: view_count,
      image: display_image.as_indexed_hash
    }
  end
  ```

2. Change [any other](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/serializer.rb#L179) serialized class (Variant, Property, Image) - again, just define `as_indexed_hash` method on your class, and follow the default logic in the `ElasticRepresentation` module.


3. Change the [SerializationIterator preloader](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/serializer.rb#L17)

  You have two options:

  a) redefine the full [Serializer class](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/serializer.rb#L4) by creating and [specifying a Serializer class](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/configuration.rb#L12) of your own.

    ```ruby
    # config/initializers/spree.rb or so
    Solidus::Elastic::Config.serializer_class = MyElasticSerializer
    ```

    Your custom _serializer_class_ must respond to `#generate_json` method and define an ActiveRecord refinement method `#each_for_serialization` to preload associations. See the default [Product::Serializer](https://github.com/boomerdigital/solidus_elastic_search/blob/master/app/models/solidus/elastic/product/serializer.rb) as an example.


  b) do the decorator drill, and for example re-define only the [`each_for_serialization`](https://github.com/boomerdigital/solidus_elastic_product/blob/master/app/models/solidus/elastic_product/serializer.rb#L30) iterator. Ex:

    ```ruby
    # solidus/elastic_product/serializer_decorator.rb
    module Solidus::ElasticProduct::Serializer::SerializationIterator
      refine ActiveRecord::Relation do
        def each_for_serialization &blk
          # your code
        end
      end
    end
    ```


### To set-up background workers

To perform the serialization, ideally, you'd have multiple single threaded processes as it is a CPU intensive task. A sidekiq example would be:


```
# config/deploy.rb
set :sidekiq_processes, 3

set :sidekiq_options_per_process, [
  "--config config/sidekiq.yml",
  "--config config/sidekiq-single-concurrency.yml",
  "--config config/sidekiq-single-concurrency.yml"
```

```
# config/sidekiq-single-concurrency.yml
:concurrency: 1
:queues:
  - elastic_serializer
  - paperclip
```

For upload - although you can upload in parallel, it could be advisable to avoid overwhelming the Elastic indexer with concurrent requests, but instead only have a single process single thread upload worker. The upload operation on the worker is not the bottleneck in this case, so there is little to gain in parallelizing that.


To run a sandbox app
-------
    cd spec/dummy
    bin/rake db:drop
    bin/rake db:reset
    bin/rake spree_sample:load


Install ElasticSearch
-------
  - Install Java - `sudo apt-get install openjdk-8-jre`
  - [Follow elastic guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html) to install
  - Install [Kibana](https://www.elastic.co/guide/en/kibana/current/deb.html) for a user interface to elastic


Testing
-------

First bundle your dependencies, then run `rake`. `rake` will default to building the dummy app if it does not exist, then it will run specs, and [Rubocop](https://github.com/bbatsov/rubocop) static code analysis (_not yet_). The dummy app can be regenerated by using `rake test_app`.

```shell
bundle
bundle exec rake test_app
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'solidus_elastic_product/factories'
```

Copyright (c) 2016 Martin Tomov; Eric Anderson, released under the New BSD License
