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

  it 'passes options to optional and splat call methods' do
    optional = Class.new do
      def call(options = {})
        options[:body]
      end
    end.new
    variadic = Class.new do
      def call(*args)
        args.first[:body]
      end
    end.new
    options = { body: 'body', headers: { 'X-Optional' => optional, 'X-Splat' => variadic } }
    described_class.new({}, options).call
    expect(options[:headers]).to eq('X-Optional' => 'body', 'X-Splat' => 'body')
  end

  it 'preserves Method header values' do
    receiver = Object.new
    def receiver.header
      'method'
    end
    options = { headers: { 'X-Method' => receiver.method(:header) } }
    described_class.new({}, options).call
    expect(options[:headers]).to eq('X-Method' => 'method')
  end

  it 'evaluates only the winning header once through the client API' do
    calls = 0
    callable = Class.new do
      def initialize(block)
        @block = block
      end
      def call
        @block.call
      end
    end.new(-> { calls += 1; 'request value' })
    client = Class.new { include HTTParty }
    client.headers 'X-Value' => -> { raise 'overridden global must not run' }
    stub_request(:get, 'http://example.test/').with(headers: { 'X-Value' => 'request value' }).to_return(body: 'ok')

    expect(client.get('http://example.test/', headers: { 'X-Value' => callable }).body).to eq('ok')
    expect(calls).to eq(1)
  end
end
