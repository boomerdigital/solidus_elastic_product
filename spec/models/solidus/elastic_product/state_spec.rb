require 'spec_helper'

module Solidus::ElasticProduct
  describe State do

    describe "elastic's indexing interface at instance level" do
      specify { expect(subject).to respond_to(:index_document) }
      specify { expect(subject).to respond_to(:delete_document) }
      specify { expect(subject).to respond_to(:update_document) }
    end


    describe '#needing_serialization' do
      it 'can find all that need serialized' do
        without_json = create :product
        deleted = create :product, deleted_at: Time.current
        with_json = create :product_with_elastic_state, json: '{}'
        locked = create :product_with_elastic_state, locked_for_serialization_at: Time.current
        expired_lock = create :product_with_elastic_state, locked_for_serialization_at: 1.month.ago

        expect( described_class.needing_serialization ).to eq \
          [without_json.elastic_state, expired_lock.elastic_state]
      end
    end

    describe '#needing_upload' do
      it 'can find all that need uploading' do
        not_serialized = create :product
        not_serialized_but_deleted = create :product, deleted_at: Time.current
        not_uploaded = create :product_with_elastic_state, json: '{}'
        already_uploaded = create :product_with_elastic_state, json: '{}', uploaded: true
        locked = create :product_with_elastic_state, json: '{}', locked_for_upload_at: Time.current
        expired_lock = create :product_with_elastic_state, json: '{}', locked_for_upload_at: 1.month.ago

        expect( described_class.needing_upload ).to eq \
          [not_serialized_but_deleted.elastic_state, not_uploaded.elastic_state,
            expired_lock.elastic_state]
      end
    end

    describe '#not_indexable' do
      it 'returns only deleted records' do
        deleted = create(:product).tap {|p| p.destroy }
        not_deleted = create :product
        expect( described_class.not_indexable ).to eq [deleted.elastic_state]
      end
    end

    describe '#indexable' do
      it 'returns only records not deleted' do
        not_deleted = create :product
        deleted = create(:product).tap {|p| p.destroy }
        expect( described_class.indexable ).to eq [not_deleted.elastic_state]
      end
    end

    describe '#mark_uploaded' do
      it 'can mark a scope of records uploaded' do
        pending_upload = create :elastic_state, json: '{}', locked_for_upload_at: Time.current
        described_class.all.mark_uploaded!

        state = pending_upload.reload
        expect( state.uploaded ).to eq true
        expect( state.locked_for_upload_at ).to be nil
      end
    end

    describe '#reset_all!' do
      it 'will reset the data on a collection' do
        state = create :elastic_state, json: '{}', locked_for_upload_at: Time.current, uploaded: true
        described_class.all.reset_all!

        state.reload
        expect( state.json ).to be nil
        expect( state.uploaded ).to be false
        expect( state.locked_for_upload_at ).to be nil
      end
    end

    describe '#reset!' do
      it 'can reset the state' do
        state = create :elastic_state, json: '{}', uploaded: true
        state.reset!
        expect( state.json ).to be nil
        expect( state.uploaded ).to be false
      end
    end

    describe '#generate_json!' do
      let(:state) { create :elastic_state, json: '{}', locked_for_serialization_at: Time.current }
      let(:product) { Spree::Product.new }
      let(:serializer) {
        instance_double Serializer,
          generate_indexed_json: "json"
      }

      before do
        state.product = product
        allow(Serializer).to receive(:new).with(product).and_return serializer
      end

      it 'stores the generated hash and clears the lock' do
        state.generate_json!

        expect( state.json ).to eq 'json'
        expect( state.locked_for_serialization_at ).to be nil
      end
    end

    describe '#as_indexed_json' do
      it 'returns the contents of the json column ready for upload to elastic' do
        subject.json = 'some-json'
        expect(subject.as_indexed_json).to eq 'some-json'
      end
    end
  end
end
