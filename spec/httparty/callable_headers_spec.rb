require 'spec_helper'

RSpec.describe HTTParty::HeadersProcessor, 'callable header objects' do
  it 'calls a zero-argument object as a global header value' do
    callable = Class.new do
      def call
        'from object'
      end
    end.new
    options = { headers: {} }
    described_class.new({ 'X-Value' => callable }, options).call
    expect(options[:headers]).to eq('X-Value' => 'from object')
  end

  it 'passes request options to a one-argument header object' do
    callable = Class.new do
      def call(options)
        options[:body].upcase
      end
    end.new
    options = { body: 'body', headers: { 'X-Value' => callable } }
    described_class.new({}, options).call
    expect(options[:headers]).to eq('X-Value' => 'BODY')
  end

  it 'keeps strict zero-argument and request-option lambda behavior' do
    options = { body: 'body', headers: { 'X-Zero' => -> { 'zero' }, 'X-One' => ->(request) { request[:body] } } }
    described_class.new({}, options).call
    expect(options[:headers]).to eq('X-Zero' => 'zero', 'X-One' => 'body')
  end
end
