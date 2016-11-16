require 'spec_helper'

module Solidus::ElasticProduct
  describe Configuration, type: :model do

    subject { described_class.new }

    specify { expect(subject.incremental_update_enabled).to be true }

    it "uses default serializer class by default" do
      expect(subject.serializer_class).to eq Serializer
    end
  end
end
