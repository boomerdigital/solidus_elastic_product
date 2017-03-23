require "spec_helper"

describe Spree::Product do
  let(:product) { build_stubbed(:product) }

  subject { product }

  describe 'auto-create elastic state' do
    let(:product) { create(:product) }
    specify { expect(subject.elastic_state).to be_persisted }
  end

  describe '#indexed_popularity' do
    before { allow(product).to receive(:line_items) { [double, double] } }
    specify { expect(subject.indexed_popularity).to eq(2) }
  end

  describe '#indexed_price' do
    let(:product) { create(:product) }
    specify { expect(subject.indexed_price).to eq(19.99) }
  end

  describe '#indexable_product_properties' do
    specify { expect(subject.indexable_product_properties).to eq([]) }
  end

  describe '#indexable_classifications' do
    specify { expect(subject.indexable_classifications).to eq([]) }
  end

  describe '#reset_index_state', no_transaction: true do
    let(:product) { create(:product) }

    it "resets the state on record change/touch" do
      expect(subject.elastic_state).to receive(:reset!)
      subject.touch
    end

    it "resets the state on destroy" do
      expect(subject.elastic_state).to receive(:reset!)
      subject.destroy!
    end
  end
end
