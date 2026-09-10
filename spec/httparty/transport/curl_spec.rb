require 'spec_helper'

RSpec.describe HTTParty::Transport::Curl do
  class FakeCurlEasy
    attr_accessor :follow_location, :headers, :connect_timeout_ms, :timeout_ms,
                  :proxy_url, :proxy_port, :proxypwd, :ssl_verify_peer,
                  :ssl_verify_host, :cacert, :interface, :local_port, :verbose
    attr_reader :method, :request_body, :settings

    def initialize
      @settings = {}
    end

    def on_header(&block)
      @header_callback = block
    end

    def on_body(&block)
      @body_callback = block
    end

    def http_get
      complete('GET')
    end

    def http_post(body)
      complete('POST', body)
    end

    def http_put(body)
      complete('PUT', body)
    end

    def http_patch(body)
      complete('PATCH', body)
    end

    def http_delete
      complete('DELETE')
    end

    def http_head
      complete('HEAD', nil, [])
    end

    def http(method, body = nil)
      complete(method, body)
    end

    def response_code
      200
    end

    def body_str
      'hello'
    end

    alias body body_str

    def set(name, value)
      settings[name] = value
    end

    def setopt(name, value)
      settings[name] = value
    end

    private

    def complete(method, body = nil, chunks = %w[hel lo])
      @method = method
      @request_body = body
      ["HTTP/1.1 200 OK\r\n", "Content-Type: text/plain\r\n", "\r\n"].each do |line|
        @header_callback.call(line)
      end
      chunks.each { |chunk| @body_callback.call(chunk) } if @body_callback
      true
    end
  end

  let(:easy) { FakeCurlEasy.new }
  let(:request_options) { {} }
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

  before do
    allow(::Curl::Easy).to receive(:new).and_return(easy)
  end

  it_behaves_like 'an HTTParty transport'

  it 'applies request headers, timeouts, proxy, TLS, and bind options' do
    request_options.merge!(
      timeout: 5,
      open_timeout: 2.5,
      http_proxyaddr: 'proxy.example.com',
      http_proxyport: 8080,
      http_proxyuser: 'user',
      http_proxypass: 'secret',
      verify: false,
      ssl_ca_file: '/tmp/ca.pem',
      local_host: '127.0.0.2',
      local_port: 12_345
    )

    transport.perform(request)

    expect(easy.headers).to eq(['accept: text/plain'])
    expect(easy.connect_timeout_ms).to eq(2_500)
    expect(easy.timeout_ms).to eq(5_000)
    expect(easy.proxy_url).to eq('proxy.example.com')
    expect(easy.proxy_port).to eq(8080)
    expect(easy.proxypwd).to eq('user:secret')
    expect(easy.ssl_verify_peer).to be(true)
    expect(easy.ssl_verify_host).to eq(2)
    expect(easy.cacert).to eq('/tmp/ca.pem')
    expect(easy.interface).to eq('127.0.0.2')
    expect(easy.local_port).to eq(12_345)
  end

  it 'can disable TLS certificate verification' do
    request_options[:verify] = false

    transport.perform(request)

    expect(easy.ssl_verify_peer).to be(false)
    expect(easy.ssl_verify_host).to eq(0)
  end

  it 'sends the normalized method and body' do
    post_request = HTTParty::Transport::Request.new(
      method: :post,
      uri: URI('https://example.com/path'),
      headers: {},
      body: 'payload',
      body_stream: nil
    )

    transport.perform(post_request)

    expect(easy.method).to eq('POST')
    expect(easy.request_body).to eq('payload')
  end

  it 'does not inherit proxy settings from the environment' do
    transport.perform(request)

    expect(easy.proxy_url).to eq('')
  end

  it 'supports namespaced curb options' do
    configured_transport = described_class.new(curb_options: { dns_cache_timeout: 60 })

    configured_transport.perform(request)

    expect(easy.settings[:dns_cache_timeout]).to eq(60)
  end

  it 'rejects curb options owned by the transport' do
    expect do
      described_class.new(curb_options: { follow_location: true })
    end.to raise_error(
      HTTParty::Transport::UnsupportedOption,
      'curl transport owns these curb options: follow_location'
    )
  end

  it 'rejects unknown transport options' do
    expect do
      described_class.new(unknown: true)
    end.to raise_error(
      HTTParty::Transport::UnsupportedOption,
      'curl transport does not support: unknown'
    )
  end

  it 'rejects Net::HTTP-specific persistent connections' do
    request_options[:persistent_connections] = {}

    expect do
      transport.perform(request)
    end.to raise_error(
      HTTParty::Transport::UnsupportedOption,
      /persistent_connections/
    )
  end

  it 'raises an actionable error when curb is unavailable' do
    unloaded_transport = described_class.allocate
    allow(unloaded_transport).to receive(:require).with('curb').and_raise(LoadError)

    expect do
      unloaded_transport.send(:require_curb)
    end.to raise_error(
      HTTParty::Transport::UnavailableError,
      'curl transport requires the curb gem; add `gem "curb"` to your bundle'
    )
  end

  it 'normalizes curb network errors' do
    allow(easy).to receive(:http_get).and_raise(::Curl::Err::ConnectionFailedError, 'connection failed')

    expect do
      transport.perform(request)
    end.to raise_error(HTTParty::Transport::NetworkError, 'connection failed')
  end

  context 'with a real libcurl request', :curl_integration do
    let(:server) { PersistentHTTPTestServer.new }

    before do
      allow(::Curl::Easy).to receive(:new).and_call_original
      WebMock.allow_net_connect!
    end

    after do
      server.stop
      WebMock.disable_net_connect!
    end

    it 'can be selected by name and follows redirects through HTTParty' do
      client = Class.new do
        include HTTParty
        transport :curl
      end

      response = client.get("http://127.0.0.1:#{server.port}/redirect")

      expect(response.code).to eq(200)
      expect(response.body).to eq('final')
      expect(server.paths).to eq(['/redirect', '/final'])
    ensure
      client&.close
    end
  end
end
