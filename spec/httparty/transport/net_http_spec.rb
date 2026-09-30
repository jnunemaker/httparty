require 'spec_helper'

RSpec.describe HTTParty::Transport::NetHttp do
  let(:native_response) do
    Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
      allow(response).to receive(:body).and_return('hello')
      allow(response).to receive(:read_body).and_yield('hel').and_yield('lo')
      response.initialize_http_header('Content-Type' => 'text/plain')
    end
  end
  let(:connection) do
    instance_double(Net::HTTP).tap do |http|
      allow(http).to receive(:request) do |_request, &block|
        block.call(native_response) if block
        native_response
      end
    end
  end
  let(:request_options) { { timeout: 5, connection_adapter: connection_adapter } }
  let(:connection_adapter) { double('connection adapter', call: connection) }
  let(:request) do
    HTTParty::Transport::Request.new(
      method: :get,
      uri: URI('https://example.com/path'),
      headers: { 'accept' => ['text/plain'] },
      body: nil,
      body_stream: nil,
      options: request_options
    )
  end
  subject(:transport) { described_class.new }

  let(:perform_request) { transport.perform(request) }
  let(:perform_streaming_request) do
    lambda do |&block|
      transport.perform(request, &block)
    end
  end

  it_behaves_like 'an HTTParty transport'

  it 'rejects unknown transport options' do
    expect do
      described_class.new(unknown: true)
    end.to raise_error(
      HTTParty::Transport::UnsupportedOption,
      'net_http transport does not support: unknown'
    )
  end

  it 'uses the configured connection adapter' do
    expect(connection_adapter).to receive(:call)
      .with(request.uri, request_options)
      .and_return(connection)

    transport.perform(request)
  end

  it 'builds a Net::HTTP request from the normalized request' do
    expect(connection).to receive(:request) do |native_request|
      expect(native_request).to be_a(Net::HTTP::Get)
      expect(native_request.path).to eq('/path')
      expect(native_request.get_fields('Accept')).to eq(['text/plain'])
      native_response
    end

    transport.perform(request)
  end

  it 'preserves a prepared native request when provided' do
    native_request = Net::HTTP::Get.new('/prepared')
    request = HTTParty::Transport::Request.new(
      method: :get,
      uri: URI('https://example.com/prepared'),
      headers: {},
      body: nil,
      body_stream: nil,
      native: native_request,
      options: request_options
    )

    expect(connection).to receive(:request).with(native_request).and_return(native_response)

    transport.perform(request)
  end
end
