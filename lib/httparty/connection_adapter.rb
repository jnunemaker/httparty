module HTTParty
  # Default connection adapter that returns a new Net::HTTP each time
  #
  # == Custom Connection Factories
  #
  # If you like to implement your own connection adapter, subclassing
  # HTTPParty::ConnectionAdapter will make it easier. Just override
  # the #connection method. The uri and options attributes will have
  # all the info you need to construct your http connection. Whatever
  # you return from your connection method needs to adhere to the
  # Net::HTTP interface as this is what HTTParty expects.
  #
  # @example log the uri and options
  #   class LoggingConnectionAdapter < HTTParty::ConnectionAdapter
  #     def connection
  #       puts uri
  #       puts options
  #       Net::HTTP.new(uri)
  #     end
  #   end
  #
  # @example count number of http calls
  #   class CountingConnectionAdapter < HTTParty::ConnectionAdapter
  #     @@count = 0
  #
  #     self.count
  #       @@count
  #     end
  #
  #     def connection
  #       self.count += 1
  #       super
  #     end
  #   end
  #
  # === Configuration
  # There is lots of configuration data available for your connection adapter
  # in the #options attribute. It is up to you to interpret them within your
  # connection adapter. Take a look at the implementation of
  # HTTParty::ConnectionAdapter#connection for examples of how they are used.
  # Some things that are probably interesting are as follows:
  # * :+timeout+: timeout in seconds
  # * :+open_timeout+: http connection open_timeout in seconds, overrides timeout if set
  # * :+read_timeout+: http connection read_timeout in seconds, overrides timeout if set
  # * :+debug_output+: see HTTParty::ClassMethods.debug_output.
  # * :+pem+: contains pem data. see HTTParty::ClassMethods.pem.
  # * :+verify+: verify the server’s certificate against the ca certificate.
  # * :+verify_peer+: set to false to turn off server verification but still send client certificate
  # * :+ssl_ca_file+: see HTTParty::ClassMethods.ssl_ca_file.
  # * :+ssl_ca_path+: see HTTParty::ClassMethods.ssl_ca_path.
  # * :+connection_adapter_options+: contains the hash you passed to HTTParty.connection_adapter when you configured your connection adapter
  class ConnectionAdapter
    # Private: Regex used to strip brackets from IPv6 URIs.
    StripIpv6BracketsRegex = /\A\[(.*)\]\z/

    # Public
    def self.call(uri, options)
      new(uri, options).connection
    end

    attr_reader :uri, :options

    def initialize(uri, options = {})
      uri_adapter = options[:uri_adapter] || URI
      raise ArgumentError, "uri must be a #{uri_adapter}, not a #{uri.class}" unless uri.is_a? uri_adapter

      @uri = uri
      @options = options
    end

    def connection
      host = clean_host(uri.host)
      port = uri.port || (uri.scheme == 'https' ? 443 : 80)
      if options[:http_proxyaddr]
        http = Net::HTTP.new(host, port, options[:http_proxyaddr], options[:http_proxyport], options[:http_proxyuser], options[:http_proxypass])
      else
        http = Net::HTTP.new(host, port)
      end

      http.use_ssl = ssl_implied?(uri)

      attach_ssl_certificates(http, options)

      if options[:timeout] && (options[:timeout].is_a?(Integer) || options[:timeout].is_a?(Float))
        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]
      end

      if options[:read_timeout] && (options[:read_timeout].is_a?(Integer) || options[:read_timeout].is_a?(Float))
        http.read_timeout = options[:read_timeout]
      end

      if options[:open_timeout] && (options[:open_timeout].is_a?(Integer) || options[:open_timeout].is_a?(Float))
        http.open_timeout = options[:open_timeout]
      end

      if options[:debug_output]
        http.set_debug_output(options[:debug_output])
      end

      if options[:ciphers]
        http.ciphers = options[:ciphers]
      end

      # Bind to a specific local address or port
      #
      # @see https://bugs.ruby-lang.org/issues/6617
      if options[:local_host]
        if RUBY_VERSION >= "2.0.0"
          http.local_host = options[:local_host]
        else
          Kernel.warn("Warning: option :local_host requires Ruby version 2.0 or later")
        end
      end

      if options[:local_port]
        if RUBY_VERSION >= "2.0.0"
          http.local_port = options[:local_port]
        else
          Kernel.warn("Warning: option :local_port requires Ruby version 2.0 or later")
        end
      end

      http
    end

    private

    def clean_host(host)
      strip_ipv6_brackets(host)
    end

    def strip_ipv6_brackets(host)
      StripIpv6BracketsRegex =~ host ? $1 : host
    end

    def ssl_implied?(uri)
      uri.port == 443 || uri.scheme == 'https'
    end

    def attach_ssl_certificates(http, options)
      if http.use_ssl?
        if options.fetch(:verify, true)
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          if options[:cert_store]
            http.cert_store = options[:cert_store]
          else
            # Use the default cert store by default, i.e. system ca certs
            http.cert_store = OpenSSL::X509::Store.new
            http.cert_store.set_default_paths
          end
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        # Client certificate authentication
        # Note: options[:pem] must contain the content of a PEM file having the private key appended
        if options[:pem]
          http.cert = OpenSSL::X509::Certificate.new(options[:pem])
          http.key = OpenSSL::PKey::RSA.new(options[:pem], options[:pem_password])
          http.verify_mode = options[:verify_peer] == false ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        end

        # PKCS12 client certificate authentication
        if options[:p12]
          p12 = OpenSSL::PKCS12.new(options[:p12], options[:p12_password])
          http.cert = p12.certificate
          http.key = p12.key
          http.verify_mode = options[:verify_peer] == false ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        end

        # SSL certificate authority file and/or directory
        if options[:ssl_ca_file]
          http.ca_file = options[:ssl_ca_file]
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        if options[:ssl_ca_path]
          http.ca_path = options[:ssl_ca_path]
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        # This is only Ruby 1.9+
        if options[:ssl_version] && http.respond_to?(:ssl_version=)
          http.ssl_version = options[:ssl_version]
        end
      end
    end
  end
end
