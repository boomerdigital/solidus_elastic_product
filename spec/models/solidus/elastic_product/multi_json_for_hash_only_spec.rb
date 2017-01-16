require "spec_helper"

describe Solidus::ElasticProduct::MultiJsonForHashOnly do

  it 'uses MultiJson' do
    expect(described_class).to respond_to(:load)
    expect(described_class).to respond_to(:dump)
  end

  describe '#dump' do
    context 'when string' do
      it 'returns the string back unchanged' do
        expect(described_class.dump('{}')).to eq('{}')
      end
    end

    context 'when hash' do
      it 'serializes it as per usual' do
        expect(described_class.dump({})).to eq('{}')
      end
    end
  end

  describe 'default api serializer' do
    it 'uses our custom one' do
      expect(Elasticsearch::API.serializer).to eq(described_class)
    end
  end
end
