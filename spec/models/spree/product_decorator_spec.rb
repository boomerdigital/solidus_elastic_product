require "spec_helper"

describe Spree::Product do
  let(:product) { build_stubbed(:product) }

  subject { product }

  describe 'auto-create elastic state' do
    let(:product) { create(:product) }
    specify { expect(subject.elastic_state).to be_persisted }
  end

  describe '#indexable_product_properties' do
    specify { expect(subject.indexable_product_properties).to eq([]) }
  end

  describe '#indexable_classifications' do
    specify { expect(subject.indexable_classifications).to eq([]) }
  end
end
