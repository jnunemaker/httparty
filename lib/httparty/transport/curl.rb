# frozen_string_literal: true

module HTTParty
  module Transport
    class Curl
      OWNED_CURB_OPTIONS = %i[
        body_str customrequest encoding fail_on_error follow_location head
        header_in_body header_str headers nobody on_body on_header post
        post_body put put_data upload url
      ].freeze

      UNSUPPORTED_REQUEST_OPTIONS = {
        cert_store: 'OpenSSL certificate stores',
        max_retries: 'automatic retries',
        p12: 'PKCS12 client certificates',
        pem: 'in-memory PEM client certificates',
        persistent_connections: 'net-http-persistent connections',
        ssl_ca_path: 'OpenSSL CA directories',
        ssl_version: 'Ruby OpenSSL version selectors'
      }.freeze

      def initialize(options = {})
        require_curb
        unknown_options = options.keys - [:curb_options]
        unless unknown_options.empty?
          raise UnsupportedOption, "curl transport does not support: #{unknown_options.join(', ')}"
        end

        @curb_options = options.fetch(:curb_options, {})
        unless @curb_options.is_a?(Hash)
          raise ArgumentError, 'curb_options must be a hash'
        end
        @curb_options = @curb_options.dup.freeze
        validate_curb_options
      end

      def perform(request)
        validate_request_options(request.options)
        easy = ::Curl::Easy.new(request.uri.to_s)
        configure(easy, request)

        response = nil
        parser = HeaderParser.new
        easy.on_header { |line| parser << line }
        if block_given?
          easy.on_body do |bytes|
            response ||= build_response(easy, parser)
            yield Chunk.new(bytes: bytes, response: response, connection_info: easy)
            bytes.bytesize
          end
        end

        perform_request(easy, request)
        response || build_response(easy, parser)
      rescue ::Curl::Err::CurlError => e
        raise NetworkError, e.message
      end

      def close
      end

      private

      def require_curb
        require 'curb'
      rescue LoadError
        raise UnavailableError, 'curl transport requires the curb gem; add `gem "curb"` to your bundle'
      end

      def validate_curb_options
        owned = @curb_options.keys.map(&:to_sym) & OWNED_CURB_OPTIONS
        return if owned.empty?

        raise UnsupportedOption, "curl transport owns these curb options: #{owned.join(', ')}"
      end

      def validate_request_options(options)
        unsupported = UNSUPPORTED_REQUEST_OPTIONS.each_with_object([]) do |(name, description), found|
          found << "#{name} (#{description})" if options[name]
        end
        return if unsupported.empty?

        raise UnsupportedOption, "curl transport does not support: #{unsupported.join(', ')}"
      end

      def configure(easy, request)
        easy.follow_location = false
        easy.headers = request.headers.flat_map do |name, values|
          Array(values).map { |value| "#{name}: #{value}" }
        end
        configure_timeouts(easy, request.options)
        configure_proxy(easy, request.options)
        configure_ssl(easy, request.options)
        configure_network(easy, request.options)
        configure_debug_output(easy, request.options[:debug_output])
        apply_curb_options(easy)
      end

      def configure_timeouts(easy, options)
        connect_timeout = options[:open_timeout] || options[:timeout]
        transfer_timeout = options[:read_timeout] || options[:write_timeout] || options[:timeout]
        easy.connect_timeout_ms = milliseconds(connect_timeout) if connect_timeout
        easy.timeout_ms = milliseconds(transfer_timeout) if transfer_timeout
      end

      def configure_proxy(easy, options)
        unless options[:http_proxyaddr]
          easy.proxy_url = ''
          return
        end

        easy.proxy_url = options[:http_proxyaddr]
        easy.proxy_port = options[:http_proxyport] if options[:http_proxyport]
        if options[:http_proxyuser] || options[:http_proxypass]
          easy.proxypwd = "#{options[:http_proxyuser]}:#{options[:http_proxypass]}"
        end
      end

      def configure_ssl(easy, options)
        verify = options.fetch(:verify, true) && options.fetch(:verify_peer, true)
        verify = true if options[:ssl_ca_file]
        easy.ssl_verify_peer = verify
        easy.ssl_verify_host = verify ? 2 : 0
        easy.cacert = options[:ssl_ca_file] if options[:ssl_ca_file]
        easy.set(:ssl_cipher_list, Array(options[:ciphers]).join(':')) if options[:ciphers]
      end

      def configure_network(easy, options)
        easy.interface = options[:local_host] if options[:local_host]
        easy.local_port = options[:local_port] if options[:local_port]
      end

      def configure_debug_output(easy, output)
        return unless output

        easy.verbose = true
        easy.setopt(::Curl::CURLOPT_STDERR, output)
      end

      def apply_curb_options(easy)
        @curb_options.each do |name, value|
          setter = "#{name}="
          if easy.respond_to?(setter)
            easy.public_send(setter, value)
          else
            easy.set(name, value)
          end
        end
      end

      def perform_request(easy, request)
        body = request.body_stream ? read_body_stream(request.body_stream) : request.body

        case request.method
        when 'GET'
          body ? easy.http('GET', body) : easy.http_get
        when 'POST'
          easy.http_post(body || '')
        when 'PUT'
          easy.http_put(body || '')
        when 'PATCH'
          easy.http_patch(body || '')
        when 'DELETE'
          body ? easy.http('DELETE', body) : easy.http_delete
        when 'HEAD'
          easy.http_head
        else
          body ? easy.http(request.method, body) : easy.http(request.method)
        end
      end

      def read_body_stream(stream)
        return stream.read if stream.respond_to?(:read)

        raise UnsupportedOption, 'curl transport body_stream must respond to #read'
      end

      def build_response(easy, parser)
        Response.new(
          code: parser.code || easy.response_code,
          headers: parser.headers,
          body: easy.body_str,
          http_version: parser.http_version,
          reason_phrase: parser.reason_phrase,
          native: easy,
          connection_info: easy
        )
      end

      def milliseconds(seconds)
        (seconds.to_f * 1_000).to_i
      end

      class HeaderParser
        STATUS_LINE = %r{\AHTTP/(\S+)\s+(\d{3})(?:\s+(.*?))?\r?\n\z}.freeze

        attr_reader :code, :headers, :http_version, :reason_phrase

        def initialize
          reset
        end

        def <<(line)
          if (match = STATUS_LINE.match(line))
            reset
            @http_version = match[1]
            @code = match[2].to_i
            @reason_phrase = match[3]
          elsif line != "\r\n" && line.include?(':')
            name, value = line.split(':', 2)
            @headers[name.downcase] << value.strip
          end

          line.bytesize
        end

        private

        def reset
          @code = nil
          @headers = Hash.new { |hash, key| hash[key] = [] }
          @http_version = nil
          @reason_phrase = nil
        end
      end
    end
  end
end
