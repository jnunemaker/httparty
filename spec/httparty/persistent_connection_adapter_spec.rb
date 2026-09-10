require 'spec_helper'
require 'httparty/persistent_connection_adapter'

RSpec.describe HTTParty::PersistentConnectionAdapter do
  class FakePersistentClient
    attr_reader :request_option_history, :requests
    attr_accessor :error
    attr_accessor :idle_timeout, :max_requests, :open_timeout, :read_timeout,
                  :write_timeout, :max_retries, :debug_output, :cert_store,
                  :verify_mode, :certificate, :private_key, :ca_file, :ca_path,
                  :ssl_version, :ciphers, :reuse_ssl_sessions, :ignore_eof

    def initialize
      @requests = []
      @request_option_history = []
    end

    def request(uri, request, &block)
      raise error if error

      @requests << [uri, request]
      block&.call(:response)
      :response
    end

    def current_http
      @current_http ||= Struct.new(:peer_cert).new(:certificate)
    end

    def with_request_options(options)
      @request_option_history << options
      yield
    end

    def shutdown
      @shutdown = true
    end

    def shutdown?
      @shutdown
    end
  end

  let(:uri) { URI('http://example.com/widgets') }
  let(:request) { Net::HTTP::Get.new(uri.request_uri) }
  let(:clients) { [] }
  let(:factory) do
    lambda do |_profile|
      FakePersistentClient.new.tap { |client| clients << client }
    end
  end
  let(:registry) do
    HTTParty::PersistentConnectionAdapter::Registry.new(max_profiles: 2, client_factory: factory)
  end
  let(:options) do
    {
      persistent_connections: {},
      persistent_connection_registry: registry
    }
  end

  after do
    registry.shutdown
  end

  describe '.call' do
    it 'returns a Net::HTTP-compatible connection that includes the URI when requesting' do
      connection = described_class.call(uri, options)

      expect(connection.request(request)).to eq(:response)
      expect(clients.first.requests).to eq([[uri, request]])
    end

    it 'passes response blocks through to the persistent client' do
      response = nil
      connection = described_class.call(uri, options)

      connection.request(request) { |value| response = value }

      expect(response).to eq(:response)
    end

    it 'exposes the checked-out Net::HTTP connection inside response blocks' do
      peer_cert = nil
      connection = described_class.call(uri, options)

      connection.request(request) { peer_cert = connection.peer_cert }

      expect(peer_cert).to eq(:certificate)
    end

    it 'reuses a client for the same effective connection profile' do
      2.times { described_class.call(uri, options).request(request) }

      expect(clients.length).to eq(1)
    end

    it 'keeps execution-only request overrides on the same client' do
      described_class.call(uri, options.merge(read_timeout: 1)).request(request)
      described_class.call(uri, options.merge(read_timeout: 2)).request(request)

      expect(clients.length).to eq(1)
      expect(clients.first.request_option_history).to eq([{ read_timeout: 1 }, { read_timeout: 2 }])
    end

    it 'evicts and shuts down the least recently used inactive profile' do
      described_class.call(uri, options.merge(verify: true)).request(request)
      first_client = clients.first
      described_class.call(uri, options.merge(verify: false)).request(request)
      described_class.call(uri, options.merge(local_port: 12_345)).request(request)

      expect(first_client).to be_shutdown
      expect(registry.size).to eq(2)
    end

    it 'restores common network errors wrapped by net-http-persistent' do
      wrapped_error = begin
        raise Errno::ECONNREFUSED
      rescue Errno::ECONNREFUSED
        begin
          raise Net::HTTP::Persistent::Error, 'connection refused'
        rescue Net::HTTP::Persistent::Error => error
          error
        end
      end
      clients << FakePersistentClient.new
      clients.first.error = wrapped_error
      allow(factory).to receive(:call).and_return(clients.first)

      expect do
        described_class.call(uri, options).request(request)
      end.to raise_error(Errno::ECONNREFUSED)
    end

    it 'normalizes custom URI objects and preserves port 443 SSL behavior' do
      custom_uri = Struct.new(:scheme, :host, :port, :path, :query, :userinfo)
                         .new('http', 'example.com', 443, '/widgets', nil, nil)

      described_class.call(custom_uri, options).request(request)

      normalized_uri = clients.first.requests.first.first
      expect(normalized_uri.scheme).to eq('https')
      expect(normalized_uri.host).to eq('example.com')
      expect(normalized_uri.port).to eq(443)
      expect(normalized_uri.path).to eq('/widgets')
    end
  end

  describe 'option validation' do
    it 'does not retain unrelated request data in cached profiles' do
      profile = described_class::Profile.new(
        persistent_connections: {},
        body: 'large request body',
        query: { page: 1 }
      )

      expect(profile.options).to eq({})
    end

    it 'rejects unknown normalized options' do
      expect do
        described_class.call(uri, options.merge(persistent_connections: { unknown: true }))
      end.to raise_error(ArgumentError, 'unknown persistent connection option: unknown')
    end

    it 'validates normalized option values' do
      expect do
        described_class.call(uri, options.merge(persistent_connections: { idle_timeout: -1 }))
      end.to raise_error(ArgumentError, 'idle_timeout must be nil or a non-negative number')

      expect do
        described_class.call(uri, options.merge(persistent_connections: { max_requests: 0 }))
      end.to raise_error(ArgumentError, 'max_requests must be nil or a positive integer')
    end

    it 'rejects unknown upstream options' do
      expect do
        described_class.call(
          uri,
          options.merge(persistent_connections: { net_http_persistent_options: { unknown: true } })
        )
      end.to raise_error(ArgumentError, 'unknown net-http-persistent option: unknown')
    end

    it 'rejects upstream options owned by HTTParty' do
      expect do
        described_class.call(
          uri,
          options.merge(persistent_connections: { net_http_persistent_options: { read_timeout: 1 } })
        )
      end.to raise_error(
        ArgumentError,
        'net-http-persistent option read_timeout conflicts with an HTTParty option'
      )
    end
  end

  describe HTTParty::PersistentConnectionAdapter::Registry do
    it 'builds one client when concurrent requests select the same new profile' do
      started = Queue.new
      release = Queue.new
      calls = 0
      synchronized_factory = lambda do |_profile|
        calls += 1
        started << true
        release.pop
        FakePersistentClient.new
      end
      synchronized_registry = described_class.new(client_factory: synchronized_factory)
      profile = HTTParty::PersistentConnectionAdapter::Profile.new(persistent_connections: {})
      threads = 2.times.map do
        Thread.new { synchronized_registry.request(profile) { |_client| :ok } }
      end

      started.pop
      release << true
      threads.each(&:value)

      expect(calls).to eq(1)
    ensure
      release << true if threads&.any?(&:alive?)
      threads&.each { |thread| thread.join(1) }
      synchronized_registry&.shutdown
    end

    it 'marshals as a fresh registry without live pools' do
      original = described_class.new(max_profiles: 3)

      copy = Marshal.load(Marshal.dump(original))

      expect(copy.max_profiles).to eq(3)
      expect(copy.size).to eq(0)
    ensure
      original&.shutdown
      copy&.shutdown
    end

    it 'discards a client that finishes building after shutdown' do
      started = Queue.new
      release = Queue.new
      built_clients = []
      calls = 0
      synchronized_factory = lambda do |_profile|
        calls += 1
        if calls == 1
          started << true
          release.pop
        end
        FakePersistentClient.new.tap { |client| built_clients << client }
      end
      synchronized_registry = described_class.new(client_factory: synchronized_factory)
      profile = HTTParty::PersistentConnectionAdapter::Profile.new(persistent_connections: {})
      thread = Thread.new { synchronized_registry.request(profile) { |_client| :ok } }

      started.pop
      expect { synchronized_registry.shutdown }.not_to raise_error
      release << true

      expect(thread.value).to eq(:ok)
      expect(built_clients.length).to eq(2)
      expect(built_clients.first).to be_shutdown
      expect(built_clients.last).not_to be_shutdown
      expect(synchronized_registry.size).to eq(1)
    ensure
      release << true if thread&.alive?
      thread&.join(1)
      synchronized_registry&.shutdown
    end
  end

  describe HTTParty::PersistentConnectionAdapter::ClientFactory do
    def build_client(request_options = {}, persistent_options = {})
      profile = HTTParty::PersistentConnectionAdapter::Profile.new(
        request_options.merge(persistent_connections: persistent_options)
      )
      described_class.new.call(profile)
    end

    it 'maps normalized pool and request options' do
      client = build_client(
        {
          local_host: '127.0.0.1',
          local_port: 12_345
        },
        pool_size: 3,
        idle_timeout: 10,
        max_requests: 100
      )

      expect(client.pool.instance_variable_get(:@size)).to eq(3)
      expect(client.local_host).to eq('127.0.0.1')
      expect(client.local_port).to eq(12_345)
      expect(client.idle_timeout).to eq(10)
      expect(client.max_requests).to eq(100)
    ensure
      client&.shutdown
    end


    it 'uses a conservative default pool size' do
      client = build_client

      expect(client.pool.instance_variable_get(:@size)).to eq(4)
    ensure
      client&.shutdown
    end

    it 'maps and decodes proxy credentials containing reserved characters' do
      client = build_client(
        http_proxyaddr: 'proxy.example.com',
        http_proxyport: 8080,
        http_proxyuser: 'user@example.com',
        http_proxypass: 'secret phrase'
      )

      expect(client.proxy_uri.to_s).to eq(
        'http://user%40example.com:secret+phrase@proxy.example.com:8080'
      )
      expect(client.instance_variable_get(:@proxy_args)).to eq(
        ['proxy.example.com', 8080, 'user@example.com', 'secret phrase']
      )
    ensure
      client&.shutdown
    end

    it 'maps SSL verification and advanced upstream options' do
      client = build_client(
        { verify: false },
        net_http_persistent_options: {
          reuse_ssl_sessions: false,
          ignore_eof: true
        }
      )

      expect(client.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
      expect(client.reuse_ssl_sessions).to be(false)
      expect(client.ignore_eof).to be(true)
    ensure
      client&.shutdown
    end
  end

  describe 'integration' do
    let(:server) { PersistentHTTPTestServer.new }
    let(:client_class) do
      Class.new do
        include HTTParty
        persistent_connections pool_size: 2, idle_timeout: 30
      end
    end
    let(:base_url) { "http://127.0.0.1:#{server.port}" }

    before do
      WebMock.disable!
    end

    after do
      client_class.shutdown_persistent_connections
      HTTParty.shutdown_persistent_connections
      server.stop
      WebMock.enable!
    end

    it 'reuses a TCP connection across requests' do
      2.times do
        expect(client_class.get("#{base_url}/").body).to eq('ok')
      end

      expect(server.connection_count).to eq(1)
    end

    it 'supports request-level opt-in through HTTParty.get' do
      2.times do
        expect(HTTParty.get("#{base_url}/", persistent_connections: {}).body).to eq('ok')
      end

      expect(server.connection_count).to eq(1)
    end

    it 'reuses the connection while following redirects' do
      response = client_class.get("#{base_url}/redirect")

      expect(response.body).to eq('final')
      expect(server.connection_count).to eq(1)
    end

    it 'keeps streamed responses reusable' do
      fragments = []
      client_class.get("#{base_url}/stream", stream_body: true) do |fragment|
        fragments << fragment.to_s
      end
      client_class.get("#{base_url}/")

      expect(fragments.join).to eq('onetwo')
      expect(server.connection_count).to eq(1)
    end

    it 'isolates concurrent timeout overrides' do
      short_request = Thread.new do
        client_class.get("#{base_url}/slow", read_timeout: 0.01)
      rescue Net::ReadTimeout
        :timed_out
      end
      long_request = Thread.new do
        client_class.get("#{base_url}/slow", read_timeout: 1).body
      end

      short_result = short_request.value
      long_result = long_request.value

      expect(short_result).to eq(:timed_out), "server paths: #{server.paths.inspect}"
      expect(long_result).to eq('slow'), "server paths: #{server.paths.inspect}"
    end

    it 'opens a fresh connection after explicit shutdown' do
      client_class.get("#{base_url}/")
      client_class.shutdown_persistent_connections
      client_class.get("#{base_url}/")

      expect(server.connection_count).to eq(2)
    end
  end
end
