require "spec_helper"

describe Spree::Taxon do
  let(:taxon) { create(:taxon, taxonomy: nil) }
  let(:product) { create(:product) }

  subject { taxon }

  describe '#notify_related_products' do
    before do
      product.taxons << taxon
      product.elastic_state.update_column(:json, 'some_json')
    end

    it "updates the product & state after update on data-changing attributes" do
      subject.name = 'New Name'
      subject.save!
      expect(product.elastic_state.reload.json).to be_nil
    end

    it "doesn't trigger on non-data changing" do
      subject.save!
      expect(product.elastic_state.reload.json).to eq('some_json')
    end

    it "updates the product & state after destroy" do
      subject.destroy!
      expect(product.elastic_state.reload.json).to be_nil
    end
  end
end
