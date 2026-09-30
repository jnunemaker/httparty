# frozen_string_literal: true

require 'net/http/persistent'
require 'thread'

module HTTParty
  # A Net::HTTP-compatible adapter backed by net-http-persistent.
  class PersistentConnectionAdapter
    CORE_OPTIONS = %i[
      pool_size
      idle_timeout
      max_requests
      net_http_persistent_options
    ].freeze

    RAW_OPTIONS = %i[
      extra_chain_cert
      ignore_eof
      keep_alive
      max_version
      min_version
      reuse_ssl_sessions
      ssl_timeout
      verify_callback
      verify_depth
      verify_hostname
    ].freeze

    HTTPARTY_OWNED_RAW_OPTIONS = %i[
      ca_file
      ca_path
      cert
      cert_store
      certificate
      ciphers
      debug_output
      idle_timeout
      key
      max_requests
      max_retries
      open_timeout
      pool_size
      private_key
      proxy
      read_timeout
      ssl_version
      verify_mode
      write_timeout
    ].freeze

    PROFILE_OPTIONS = %i[
      cert_store
      ciphers
      debug_output
      http_proxyaddr
      http_proxyport
      http_proxypass
      http_proxyuser
      local_host
      local_port
      p12
      p12_password
      pem
      pem_password
      ssl_ca_file
      ssl_ca_path
      ssl_version
      verify
      verify_peer
    ].freeze

    REQUEST_OPTIONS = %i[
      max_retries
      open_timeout
      read_timeout
      timeout
      write_timeout
    ].freeze

    DEFAULT_MAX_PROFILES = 16
    DEFAULT_POOL_SIZE = 4

    # An immutable description of settings that may safely share connections.
    class Profile
      attr_reader :options, :persistent_options

      def initialize(options)
        @options = PROFILE_OPTIONS.each_with_object({}) do |option, values|
          values[option] = options[option] if options.key?(option)
        end
        @persistent_options = options[:persistent_connections]
        validate!
        @key = snapshot(profile_values)
      end

      def eql?(other)
        other.is_a?(self.class) && key.eql?(other.key)
      end
      alias == eql?

      def hash
        key.hash
      end

      protected

      attr_reader :key

      private

      def validate!
        unless persistent_options.is_a?(Hash)
          raise ArgumentError, 'persistent_connections must be false or a hash'
        end

        unknown = persistent_options.keys - CORE_OPTIONS
        raise ArgumentError, "unknown persistent connection option: #{unknown.first}" if unknown.any?

        validate_positive_integer(:pool_size)
        validate_non_negative_number_or_nil(:idle_timeout)
        validate_positive_integer_or_nil(:max_requests)

        raw_options = persistent_options.fetch(:net_http_persistent_options, {})
        unless raw_options.is_a?(Hash)
          raise ArgumentError, 'net_http_persistent_options must be a hash'
        end

        conflict = raw_options.keys.find { |option| HTTPARTY_OWNED_RAW_OPTIONS.include?(option) }
        if conflict
          raise ArgumentError,
                "net-http-persistent option #{conflict} conflicts with an HTTParty option"
        end

        unknown_raw = raw_options.keys - RAW_OPTIONS
        raise ArgumentError, "unknown net-http-persistent option: #{unknown_raw.first}" if unknown_raw.any?
      end

      def validate_positive_integer(name)
        return unless persistent_options.key?(name)
        return if persistent_options[name].is_a?(Integer) && persistent_options[name].positive?

        raise ArgumentError, "#{name} must be a positive integer"
      end

      def validate_positive_integer_or_nil(name)
        return unless persistent_options.key?(name)
        value = persistent_options[name]
        return if value.nil? || (value.is_a?(Integer) && value.positive?)

        raise ArgumentError, "#{name} must be nil or a positive integer"
      end

      def validate_non_negative_number_or_nil(name)
        return unless persistent_options.key?(name)
        value = persistent_options[name]
        return if value.nil? || ((value.is_a?(Integer) || value.is_a?(Float)) && value >= 0)

        raise ArgumentError, "#{name} must be nil or a non-negative number"
      end

      def profile_values
        [persistent_options, options]
      end

      def snapshot(value)
        case value
        when Hash
          value.keys.sort_by(&:to_s).map { |key| [key, snapshot(value[key])] }.freeze
        when Array
          value.map { |item| snapshot(item) }.freeze
        when String
          value.dup.freeze
        when Symbol, Numeric, true, false, nil
          value
        else
          [value.class.name, value.object_id].freeze
        end
      end
    end

    # Adds the existing local bind options before net-http-persistent starts a
    # newly-created Net::HTTP connection.
    class Client < Net::HTTP::Persistent
      include ConnectionOptionValidation

      attr_accessor :local_host, :local_port

      def initialize(*args, **kwargs)
        super
        @current_http_key = "httparty-persistent-http-#{object_id}"
        @request_options_key = "httparty-persistent-request-options-#{object_id}"
      end

      def connection_for(uri)
        super do |connection|
          Thread.current[@current_http_key] = connection.http
          apply_request_options(connection.http)
          yield connection
        ensure
          Thread.current[@current_http_key] = nil
        end
      end

      def current_http
        Thread.current[@current_http_key]
      end

      def with_request_options(options)
        previous = Thread.current[@request_options_key]
        Thread.current[@request_options_key] = options
        yield
      ensure
        Thread.current[@request_options_key] = previous
      end

      def start(http)
        apply_open_timeout(http)
        http.local_host = local_host if local_host
        http.local_port = local_port if local_port
        super
      end

      private

      def request_options
        Thread.current[@request_options_key] || {}
      end

      def defaults_for(http)
        defaults = http.instance_variable_get(:@httparty_persistent_defaults)
        return defaults if defaults

        defaults = {
          open_timeout: http.open_timeout,
          read_timeout: http.read_timeout,
          max_retries: http.max_retries
        }
        defaults[:write_timeout] = http.write_timeout if http.respond_to?(:write_timeout)
        http.instance_variable_set(:@httparty_persistent_defaults, defaults)
        defaults
      end

      def apply_open_timeout(http)
        defaults = defaults_for(http)
        http.open_timeout = option_value(:open_timeout, defaults[:open_timeout])
      end

      def apply_request_options(http)
        defaults = defaults_for(http)
        http.read_timeout = option_value(:read_timeout, defaults[:read_timeout])
        if http.respond_to?(:write_timeout=)
          http.write_timeout = option_value(:write_timeout, defaults[:write_timeout])
        end
        http.max_retries = retry_value(defaults[:max_retries]) if http.respond_to?(:max_retries=)
      end

      def option_value(name, default)
        specific = request_options[name]
        return specific if valid_timeout?(specific)

        general = request_options[:timeout]
        valid_timeout?(general) ? general : default
      end

      def retry_value(default)
        value = request_options[:max_retries]
        valid_max_retries?(value) ? value : default
      end
    end

    class ClientFactory
      def call(profile)
        options = profile.options
        persistent_options = profile.persistent_options
        constructor_options = {
          name: 'HTTParty',
          proxy: proxy_uri(options),
          pool_size: persistent_options.fetch(:pool_size, DEFAULT_POOL_SIZE)
        }

        client = Client.new(**constructor_options)
        configure_core(client, persistent_options)
        configure_connection(client, options)
        configure_ssl(client, options)
        configure_raw(client, persistent_options.fetch(:net_http_persistent_options, {}))
        client
      end

      private

      def configure_core(client, options)
        client.idle_timeout = options[:idle_timeout] if options.key?(:idle_timeout)
        client.max_requests = options[:max_requests] if options.key?(:max_requests)
      end

      def configure_connection(client, options)
        client.debug_output = options[:debug_output] if options[:debug_output]
        client.ciphers = options[:ciphers] if options[:ciphers]
        client.local_host = options[:local_host] if options[:local_host]
        client.local_port = options[:local_port] if options[:local_port]
      end

      def configure_ssl(client, options)
        if options.fetch(:verify, true)
          client.verify_mode = OpenSSL::SSL::VERIFY_PEER
          client.cert_store = options[:cert_store] || ConnectionAdapter.default_cert_store
        else
          client.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        if options[:pem]
          client.certificate = OpenSSL::X509::Certificate.new(options[:pem])
          client.private_key = OpenSSL::PKey.read(options[:pem], options[:pem_password])
          client.verify_mode = verify_ssl_certificate?(options) ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        end

        if options[:p12]
          p12 = OpenSSL::PKCS12.new(options[:p12], options[:p12_password])
          client.certificate = p12.certificate
          client.private_key = p12.key
          client.verify_mode = verify_ssl_certificate?(options) ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        end

        if options[:ssl_ca_file]
          client.ca_file = options[:ssl_ca_file]
          client.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if options[:ssl_ca_path]
          client.ca_path = options[:ssl_ca_path]
          client.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        client.ssl_version = options[:ssl_version] if options[:ssl_version]
      end

      def configure_raw(client, options)
        options.each do |name, value|
          client.public_send("#{name}=", value)
        end
      end

      def proxy_uri(options)
        address = options[:http_proxyaddr]
        return unless address

        proxy = if address.to_s.match?(%r{\Ahttps?://})
                  URI(address.to_s)
                else
                  URI::HTTP.build(host: address.to_s, port: options[:http_proxyport])
                end
        proxy.port = options[:http_proxyport] if options[:http_proxyport]
        proxy.user = escape_proxy_credential(options[:http_proxyuser]) if options[:http_proxyuser]
        proxy.password = escape_proxy_credential(options[:http_proxypass]) if options[:http_proxypass]
        proxy
      end

      def escape_proxy_credential(value)
        URI.encode_www_form_component(value.to_s)
      end

      def verify_ssl_certificate?(options)
        !(options[:verify] == false || options[:verify_peer] == false)
      end
    end

    # A bounded, concurrency-safe cache of immutable persistent clients.
    class Registry
      Entry = Struct.new(:client, :active, :last_used, :building, :condition)

      attr_reader :max_profiles

      def initialize(max_profiles: DEFAULT_MAX_PROFILES, client_factory: ClientFactory.new)
        @max_profiles = max_profiles
        @client_factory = client_factory
        @entries = {}
        @mutex = Mutex.new
        @clock = 0
      end

      def request(profile)
        entry, evicted = checkout(profile)
        shutdown_entries(evicted)
        yield entry.client
      ensure
        checkin(profile, entry) if entry
      end

      def marshal_dump
        { max_profiles: max_profiles }
      end

      def marshal_load(state)
        initialize(max_profiles: state[:max_profiles])
      end

      def size
        @mutex.synchronize { @entries.size }
      end

      def shutdown
        entries = @mutex.synchronize do
          old_entries = @entries.values
          @entries = {}
          old_entries.each { |entry| entry.condition.broadcast if entry.building }
          old_entries
        end
        shutdown_entries(entries)
      end

      private

      def checkout(profile)
        evicted = []
        entry = nil

        @mutex.synchronize do
          loop do
            entry = @entries[profile]
            if entry&.building
              entry.condition.wait(@mutex)
              next
            end

            if entry
              entry.active += 1
              entry.last_used = tick
              return [entry, evicted]
            end

            evicted = evict_inactive(1)
            entry = Entry.new(nil, 1, tick, true, ConditionVariable.new)
            @entries[profile] = entry
            break
          end
        end

        begin
          client = @client_factory.call(profile)
        rescue Exception
          @mutex.synchronize do
            @entries.delete(profile) if @entries[profile].equal?(entry)
            entry.building = false
            entry.condition.broadcast
          end
          shutdown_entries(evicted)
          raise
        end

        accepted = @mutex.synchronize do
          if @entries[profile].equal?(entry)
            entry.client = client
            entry.building = false
            entry.condition.broadcast
            true
          else
            false
          end
        end

        return [entry, evicted] if accepted

        client.shutdown
        shutdown_entries(evicted)
        checkout(profile)
      end

      def checkin(profile, entry)
        evicted = @mutex.synchronize do
          current = @entries[profile]
          if current.equal?(entry)
            current.active -= 1
            current.last_used = tick
          end
          evict_inactive(0)
        end
        shutdown_entries(evicted)
      end

      def evict_inactive(extra_slots)
        evicted = []
        while @entries.size + extra_slots > max_profiles
          profile, entry = @entries.select { |_key, value| value.active.zero? }
                                   .min_by { |_key, value| value.last_used }
          break unless entry

          @entries.delete(profile)
          evicted << entry
        end
        evicted
      end

      def shutdown_entries(entries)
        entries.each { |entry| entry.client&.shutdown }
      end

      def tick
        @clock += 1
      end
    end

    class Connection
      def initialize(uri, registry, profile, request_options)
        @uri = normalize_uri(uri)
        @registry = registry
        @profile = profile
        @request_options = request_options
      end

      def request(request, &block)
        @registry.request(@profile) do |client|
          client.with_request_options(@request_options) do
            if block
              client.request(@uri, request) do |response|
                @current_http = client.current_http
                block.call(response)
              ensure
                @current_http = nil
              end
            else
              client.request(@uri, request)
            end
          end
        end
      rescue Net::HTTP::Persistent::Error => error
        if COMMON_NETWORK_ERRORS.any? { |type| error.cause.is_a?(type) }
          raise error.cause
        end

        raise
      end

      def method_missing(name, *args, **kwargs, &block)
        if @current_http&.respond_to?(name)
          return @current_http.public_send(name, *args, **kwargs, &block)
        end

        super
      end

      def respond_to_missing?(name, include_private = false)
        (@current_http && @current_http.respond_to?(name, include_private)) || super
      end

      private

      def normalize_uri(uri)
        normalized = uri.is_a?(URI::Generic) ? uri : build_uri(uri)
        return normalized unless normalized.port == 443 && normalized.scheme == 'http'

        normalized.dup.tap { |value| value.scheme = 'https' }
      end

      def build_uri(uri)
        uri_class = uri.scheme == 'https' ? URI::HTTPS : URI::HTTP
        uri_class.build(
          host: uri.host,
          port: uri.port,
          path: uri.path,
          query: uri.query,
          userinfo: uri.userinfo
        )
      end
    end

    class << self
      def call(uri, options)
        registry = options[:persistent_connection_registry] || default_registry
        request_options = REQUEST_OPTIONS.each_with_object({}) do |name, values|
          values[name] = options[name] if options.key?(name)
        end
        Connection.new(uri, registry, Profile.new(options), request_options)
      end

      def shutdown
        default_registry.shutdown
      end

      private

      def default_registry
        @default_registry ||= Registry.new
      end
    end
  end
end
