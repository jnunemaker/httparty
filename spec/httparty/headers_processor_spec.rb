require 'spec_helper'

RSpec.describe HTTParty::HeadersProcessor do
  subject(:headers) { options[:headers] }
  let(:options) { { headers: {} } }
  let(:global_headers) { {} }

  before { described_class.new(global_headers, options).call }

  context 'when headers are not set at all' do
    it 'returns empty hash' do
      expect(headers).to eq({})
    end
  end

  context 'when only global headers are set' do
    let(:global_headers) { { accept: 'text/html' } }

    it 'returns stringified global headers' do
      expect(headers).to eq('accept' => 'text/html')
    end
  end

  context 'when only request specific headers are set' do
    let(:options) { { headers: {accept: 'text/html' } } }

    it 'returns stringified request specific headers' do
      expect(headers).to eq('accept' => 'text/html')
    end
  end

  context 'when global and request specific headers are set' do
    let(:global_headers) { { 'x-version' => '123' } }

    let(:options) { { headers: { accept: 'text/html' } } }

    it 'returns merged global and request specific headers' do
      expect(headers).to eq('accept' => 'text/html', 'x-version' => '123')
    end
  end

  context 'when headers are dynamic' do
    let(:global_headers) { {'x-version' => -> { 'abc'.reverse } } }

    let(:options) do
      { body: '123',
        headers: { sum: lambda { |options| options[:body].chars.map(&:to_i).inject(:+) } } }
    end

    it 'returns processed global and request specific headers' do
      expect(headers).to eq('sum' => 6, 'x-version' => 'cba')
    end
  end
end
