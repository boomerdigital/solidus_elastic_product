require 'spec_helper'

module Solidus::ElasticProduct
  describe ReindexJob do
    let(:indices) { instance_double(Elasticsearch::API::Indices::IndicesClient) }
    let(:client) { instance_double(Elasticsearch::Transport::Client, indices: indices ) }

    before do
      allow(Index).to receive(:client).and_return client
      allow(Index).to receive(:create_index!)
      allow(indices).to receive(:get_aliases).and_return({})
    end


    describe 'restoring incremental state' do
      let(:indices) { double('indices', get_alias: {}).as_null_object }

      before do
        allow(Index).to receive(:import)
      end

      it 'will return the incremental state to the old state when done' do
        subject.perform
        expect( Config.incremental_update_enabled ).to eq true
      end

      it 'will restore if previously false' do
        begin
          Config.incremental_update_enabled = false
          subject.perform
          expect( Config.incremental_update_enabled ).to eq false
        ensure
          Config.incremental_update_enabled = true
        end
      end
    end

    describe "#perform" do
      context 'on success' do
        let(:success_response) do
          {
            "took" => 85,
            "errors" => false,
            "items" => [
              {  # [0]
                "index" => {
                     "_index" => "products_development_20161220135033355",
                      "_type" => "spree/product",
                        "_id" => "10",
                   "_version" => 1,
                     "result" => "created",
                    "_shards" => {
                            "total" => 2,
                       "successful" => 1,
                           "failed" => 0
                   },
                    "created" => true,
                     "status" => 201
                }
              },
              {  # [1]
                "index" => {
                     "_index" => "products_development_20161220135033355",
                      "_type" => "spree/product",
                        "_id" => "20",
                   "_version" => 1,
                     "result" => "created",
                    "_shards" => {
                            "total" => 2,
                       "successful" => 1,
                           "failed" => 0
                   },
                    "created" => true,
                     "status" => 201
                }
              }
            ]
          }
        end

        it 'will upload all products using #import and mark them as uploaded' do
          allow(Index).to receive(:import).and_yield success_response
          expect(State).to receive_message_chain(:where, :not).with(id: []).and_return State
          expect(State).to receive(:mark_uploaded!)

          expect(indices).to receive(:exists_alias).with({ name: 'products_test'}).and_return true
          expect(indices).to receive(:get_alias).with({ name: 'products_test'}).and_return ({ 'old_index_name' => {} })
          expect(indices).to receive(:update_aliases).
            with({:body=>{:actions=>[
              {:remove=>{:index=>"old_index_name", :alias=>"products_test"}},
              {:add=>{:index=>/products_test/, :alias=>"products_test"}}
            ]}})

          subject.perform
        end
      end

      context 'on errors' do
        let(:error_response) do
          {
            "took" => 2,
          "errors" => true,
           "items" => [
              { # [0]
                "index" => {
                    "_index" => "products_development_20161220134534623",
                     "_type" => "spree/product",
                       "_id" => "1",
                    "status" => 400,
                     "error" => {
                             "type" => "mapper_parsing_exception",
                           "reason" => "failed to parse",
                        "caused_by" => {
                              "type" => "not_x_content_exception",
                            "reason" => "Compressor detection can only be called on some xcontent bytes or compressed xcontent bytes"
                        }
                    }
                }
              },
            ]
          }
        end

        describe 'swapping the index' do
          before do
            allow(Index).to receive(:import).and_yield error_response
          end

          context 'when less than 5% of the products have failed to index' do
            before do
              allow(State).to receive(:count).and_return(21)
            end

            it 'not mark failed to upload products as uploaded, but will still swap the index' do
              expect(State).to receive_message_chain(:where, :not).with(id: ["1"]).and_return State
              expect(State).to receive(:mark_uploaded!)

              expect(indices).to receive(:exists_alias)
              expect(indices).to receive(:update_aliases)

              subject.perform
            end
          end

          context 'when more than 5% of the products have failed to index' do
            before do
              allow(State).to receive(:count).and_return(2)
            end

            it 'not mark failed to upload products as uploaded, but will still swap the index' do
              expect(State).not_to receive(:where)
              expect(State).not_to receive(:mark_uploaded!)

              expect(indices).not_to receive(:exists_alias)
              expect(indices).not_to receive(:update_aliases)

              subject.perform
            end
          end
        end


      end
    end

  end
end
