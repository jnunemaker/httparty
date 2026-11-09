require 'spec_helper'

RSpec.describe HTTParty::Request::Body, 'hash-like multipart input' do
  let(:wrapper) do
    Class.new do
      def initialize(value)
        @value = value
      end

      def to_hash
        @value
      end
    end
  end

  it 'serializes a forced multipart hash-like object without Enumerable methods' do
    body = described_class.new(wrapper.new({ name: 'Ada' }), force_multipart: true)
    expect(body.call).to include('name="name"', 'Ada')
  end

  it 'serializes and streams files in a hash-like object with identical bytes' do
    File.open(File.expand_path('../../fixtures/tiny.gif', __dir__), 'rb') do |file|
      body = described_class.new(wrapper.new({ avatar: file, name: 'Ada' }))
      expect(body.multipart?).to be true
      buffered = body.call
      expect(body.to_stream.read).to eq(buffered)
      expect(file.pos).to eq(0)
    end
  end

  it 'retains custom normalization for non-multipart hash-like input' do
    input = wrapper.new({ name: 'Ada' })
    normalizer = ->(value) { "custom:#{value.to_hash[:name]}" }
    expect(described_class.new(input, query_string_normalizer: normalizer).call).to eq('custom:Ada')
  end

  it 'normalizes a non-multipart hash-like input through the default normalizer' do
    expect(described_class.new(wrapper.new({ name: 'Ada' })).call).to eq('name=Ada')
  end

  it 'serializes files nested in another hash-like value' do
    File.open(File.expand_path('../../fixtures/tiny.gif', __dir__), 'rb') do |file|
      body = described_class.new(wrapper.new({ user: wrapper.new({ avatar: file }) }))
      buffered = body.call
      expect(buffered).to include('name="user[avatar]"', 'filename="tiny.gif"', 'GIF89a')
      expect(body.to_stream.read).to eq(buffered)
    end
  end
end
