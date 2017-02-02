require 'spec_helper'

module Solidus::ElasticProduct
  describe Index do
    specify { expect(described_class.index_name).to be_present }

    specify { expect(described_class.document_type).to be_present }

    specify { expect(described_class.client).to be_present }

    # support all methods
    Elasticsearch::Model::METHODS.each do |method|
      specify { expect(described_class).to respond_to method }
    end

    describe "Importing interface" do
      before do
        allow(State).to receive(:serialized).and_return State
      end

      describe "#__find_in_batches" do
        it "raise an exception when passing an invalid scope" do
          expect { described_class.__find_in_batches(scope: :not_found_method) }.
            to raise_error NoMethodError
        end

        it "limit the relation to a specific scope" do
          expect(State).to receive(:find_in_batches).and_return([])
          expect(State).to receive(:published).and_return(State)
          described_class.__find_in_batches(scope: :published)
        end

        it "limit the relation to a specific query" do
          expect(State).to receive(:find_in_batches).and_return([])
          expect(State).to receive(:where).and_return(State)

          described_class.__find_in_batches(query: -> { where(color: "red") })
        end

        it "preprocess the batch if option provided" do
          class << Index
            # Updates/transforms the batch while fetching it from the database
            # (eg. with information from an external system)
            #
            def update_batch(batch)
              batch.collect { |s| s.json + '!' }
            end
          end

          expect(State).to receive(:find_in_batches).and_yield(
            [State.new(json: 'a'), State.new(json: 'b')]
          )

          described_class.__find_in_batches(preprocess: :update_batch) do |batch|
            expect(batch).to eq ["a!", "b!"]
          end
        end

        it "skips over states without json set" do
          with_json = State.new json: '{}'
          without_json = State.new
          expect(State).to receive(:find_in_batches).and_yield [with_json, without_json]

          described_class.__find_in_batches do |batch|
            expect(batch).to eq [with_json]
          end
        end
      end

      describe "#__transform" do
        subject { described_class.__transform }

        specify { expect(subject).to respond_to(:call) }

        it "provides an index transformation" do
          model = instance_double State, id: 1, as_indexed_json: '{}'
          expect(subject.call(model)).to eq( { index: { _id: 1, data: '{}' } } )
        end
      end

      describe "#transform_delete" do
        subject { described_class.transform_delete }

        it "provides a delete transformation" do
          model = instance_double State, id: 1
          expect(subject.call(model)).to eq( { delete: { _id: 1 } } )
        end
      end

    end
  end
end
