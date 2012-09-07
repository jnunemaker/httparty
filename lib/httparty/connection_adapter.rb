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
  # Something are probably interesting are as follows:
  # * :+timeout+: timeout in seconds
  # * :+debug_output+: see HTTParty::ClassMethods.debug_output.
  # * :+pem+: contains pem data. see HTTParty::ClassMethods.pem.
  # * :+ssl_ca_file+: see HTTParty::ClassMethods.ssl_ca_file.
  # * :+ssl_ca_path+: see HTTParty::ClassMethods.ssl_ca_path.
  # * :+connection_adapter_options+: contains the hash your passed to HTTParty.connection_adapter when you configured your connection adapter
  class ConnectionAdapter

    def self.call(uri, options)
      new(uri, options).connection
    end

    attr_reader :uri, :options

    def initialize(uri, options={})
      raise ArgumentError, "uri must be a URI, not a #{uri.class}" unless uri.kind_of? URI

      @uri = uri
      @options = options
    end

    def connection
      http = Net::HTTP.new(uri.host, uri.port, options[:http_proxyaddr], options[:http_proxyport], options[:http_proxyuser], options[:http_proxypass])

      http.use_ssl = ssl_implied?(uri)

      attach_ssl_certificates(http, options)

      if options[:timeout] && (options[:timeout].is_a?(Integer) || options[:timeout].is_a?(Float))
        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]
      end

      if options[:debug_output]
        http.set_debug_output(options[:debug_output])
      end

      return http
    end

    private
    def ssl_implied?(uri)
      uri.port == 443 || uri.instance_of?(URI::HTTPS)
    end

    def attach_ssl_certificates(http, options)
      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        # Client certificate authentication
        if options[:pem]
          http.cert = OpenSSL::X509::Certificate.new(options[:pem])
          http.key = OpenSSL::PKey::RSA.new(options[:pem], options[:pem_password])
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
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
