# frozen_string_literal: true

require 'erb'

module HTTParty
  class Request #:nodoc:
    SupportedHTTPMethods = [
      Net::HTTP::Get,
      Net::HTTP::Post,
      Net::HTTP::Patch,
      Net::HTTP::Put,
      Net::HTTP::Delete,
      Net::HTTP::Head,
      Net::HTTP::Options,
      Net::HTTP::Move,
      Net::HTTP::Copy,
      Net::HTTP::Mkcol,
      Net::HTTP::Lock,
      Net::HTTP::Unlock,
    ]

    SupportedURISchemes  = ['http', 'https', 'webcal', nil]

    NON_RAILS_QUERY_STRING_NORMALIZER = proc do |query|
      Array(query).sort_by { |a| a[0].to_s }.map do |key, value|
        if value.nil?
          key.to_s
        elsif value.respond_to?(:to_ary)
          value.to_ary.map {|v| "#{key}=#{ERB::Util.url_encode(v.to_s)}"}
        else
          HashConversions.to_params(key => value)
        end
      end.flatten.join('&')
    end

    JSON_API_QUERY_STRING_NORMALIZER = proc do |query|
      Array(query).sort_by { |a| a[0].to_s }.map do |key, value|
        if value.nil?
          key.to_s
        elsif value.respond_to?(:to_ary)
          values = value.to_ary.map{|v| ERB::Util.url_encode(v.to_s)}
          "#{key}=#{values.join(',')}"
        else
          HashConversions.to_params(key => value)
        end
      end.flatten.join('&')
    end

    def self._load(data)
      http_method, path, options, last_response, last_uri, raw_request = Marshal.load(data)
      instance = new(http_method, path, options)
      instance.last_response = last_response
      instance.last_uri = last_uri
      instance.instance_variable_set("@raw_request", raw_request)
      instance
    end

    attr_accessor :http_method, :options, :last_response, :redirect, :last_uri
    attr_reader :path

    def initialize(http_method, path, o = {})
      @changed_hosts = false
      @credentials_sent = false

      self.http_method = http_method
      self.options = {
        limit: o.delete(:no_follow) ? 1 : 5,
        assume_utf16_is_big_endian: true,
        default_params: {},
        follow_redirects: true,
        parser: Parser,
        uri_adapter: URI,
        connection_adapter: ConnectionAdapter,
        transport: Transport::NetHttp,
        transport_options: {}
      }.merge(o)
      self.path = path
      set_basic_auth_from_uri
    end

    def path=(uri)
      uri_adapter = options[:uri_adapter]

      @path = if uri.is_a?(uri_adapter)
        uri
      elsif String.try_convert(uri)
        uri_adapter.parse(uri).normalize
      else
        raise ArgumentError,
          "bad argument (expected #{uri_adapter} object or URI string)"
      end
    end

    def request_uri(uri)
      if uri.respond_to? :request_uri
        uri.request_uri
      else
        uri.path
      end
    end

    def uri
      if redirect && path.relative? && path.path[0] != '/'
        last_uri_host = @last_uri.path.gsub(/[^\/]+$/, '')

        path.path = "/#{path.path}" if last_uri_host[-1] != '/'
        path.path = "#{last_uri_host}#{path.path}"
      end

      if path.relative? && path.host
        new_uri = options[:uri_adapter].parse("#{@last_uri.scheme}:#{path}").normalize
      elsif path.relative?
        new_uri = options[:uri_adapter].parse("#{base_uri}#{path}").normalize
      else
        new_uri = path.clone
      end

      validate_uri_safety!(new_uri) unless redirect

      # avoid double query string on redirects [#12]
      unless redirect
        new_uri.query = query_string(new_uri)
      end

      unless SupportedURISchemes.include? new_uri.scheme
        raise UnsupportedURIScheme, "'#{new_uri}' Must be HTTP, HTTPS or Generic"
      end

      @last_uri = new_uri
    end

    def base_uri
      if redirect
        base_uri = "#{@last_uri.scheme}://#{@last_uri.host}"
        base_uri = "#{base_uri}:#{@last_uri.port}" if @last_uri.port != 80
        base_uri
      else
        options[:base_uri] && HTTParty.normalize_base_uri(options[:base_uri])
      end
    end

    def format
      options[:format] || (format_from_mimetype(transport_response['content-type']) if transport_response)
    end

    def parser
      options[:parser]
    end

    def connection_adapter
      if options[:persistent_connections]
        require 'httparty/persistent_connection_adapter'
        PersistentConnectionAdapter
      else
        options[:connection_adapter]
      end
    end

    def perform(&block)
      @perform_depth = @perform_depth.to_i + 1
      chunked_body = nil

      begin
        validate
        setup_raw_request
        self.transport_response = if block
                                    transport.perform(transport_request) do |chunk|
                                      encoded_fragment = encode_text(chunk.bytes, chunk.response['content-type'])
                                      block.call ResponseFragment.new(
                                        encoded_fragment,
                                        compatible_response(chunk.response),
                                        chunk.connection_info
                                      )
                                      chunked_body ||= +''
                                      chunked_body << encoded_fragment if !options[:stream_body]
                                    end
                                  else
                                    transport.perform(transport_request)
                                  end
        chunked_body = +'' if block && chunked_body.nil?
        self.last_response = compatible_response(transport_response)

        handle_host_redirection if response_redirects?
        result = handle_unauthorized
        result ||= handle_response(chunked_body, &block)
        result
      rescue *COMMON_NETWORK_ERRORS, Transport::NetworkError => e
        raise options[:foul] ? HTTParty::NetworkError.new("#{e.class}: #{e.message}") : e
      ensure
        @perform_depth -= 1
        if @perform_depth.zero? && options[:close_transport_after_request]
          transport.close
          @transport = nil
        end
      end
    end

    def handle_unauthorized(&block)
      return unless digest_auth? && response_unauthorized? && response_has_digest_auth_challenge?
      return if @credentials_sent
      @credentials_sent = true
      perform(&block)
    end

    def raw_body
      @raw_request.body
    end

    def _dump(_level)
      opts = options.dup
      opts.delete(:logger)
      opts.delete(:parser) if opts[:parser] && opts[:parser].is_a?(Proc)
      opts.delete(:transport_instance)
      opts.delete(:close_transport_after_request)
      Marshal.dump([http_method, path, opts, last_response, @last_uri, @raw_request])
    end

    private

    attr_writer :transport_response

    def transport
      @transport ||= options[:transport_instance] || begin
        transport_class = Transport.resolve(options[:transport] || Transport::NetHttp)
        options[:close_transport_after_request] = true
        transport_class.new(options[:transport_options] || {})
      end
    end

    def transport_request
      Transport::Request.new(
        method: http_method.const_get(:METHOD),
        uri: uri,
        headers: @raw_request.to_hash,
        body: @raw_request.body,
        body_stream: @raw_request.body_stream,
        native: @raw_request,
        options: options.merge(connection_adapter: connection_adapter)
      )
    end

    def transport_response
      @transport_response ||= if last_response
                                Transport::Response.from_native(last_response)
                              end
    end

    def compatible_response(response)
      response.native.is_a?(Net::HTTPResponse) ? response.native : response
    end

    def credentials
      (options[:basic_auth] || options[:digest_auth]).to_hash
    end

    def username
      credentials[:username]
    end

    def password
      credentials[:password]
    end

    def normalize_query(query)
      if query_string_normalizer
        query_string_normalizer.call(query)
      else
        HashConversions.to_params(query)
      end
    end

    def query_string_normalizer
      options[:query_string_normalizer]
    end

    def setup_raw_request
      if options[:headers].respond_to?(:to_hash)
        headers_hash = options[:headers].to_hash
      else
        headers_hash = nil
      end

      @raw_request = http_method.new(request_uri(uri), headers_hash)
      @raw_request.body_stream = options[:body_stream] if options[:body_stream]

      if options[:body]
        body = Body.new(
          options[:body],
          query_string_normalizer: query_string_normalizer,
          force_multipart: options[:multipart]
        )

        if body.multipart?
          content_type = "multipart/form-data; boundary=#{body.boundary}"
          @raw_request['Content-Type'] = content_type
        elsif options[:body].respond_to?(:to_hash) && !@raw_request['Content-Type']
          @raw_request['Content-Type'] = 'application/x-www-form-urlencoded'
        end

        if body.streaming? && options[:stream_body] == true
          stream = body.to_stream
          @raw_request.body_stream = stream
          @raw_request['Content-Length'] = stream.size.to_s
        else
          @raw_request.body = body.call
        end
      end

      @raw_request.instance_variable_set(:@decode_content, decompress_content?)

      if options[:basic_auth] && send_authorization_header?
        @raw_request.basic_auth(username, password)
        @credentials_sent = true
      end
      setup_digest_auth if digest_auth? && response_unauthorized? && response_has_digest_auth_challenge?
    end

    def digest_auth?
      !!options[:digest_auth]
    end

    def decompress_content?
      !options[:skip_decompression]
    end

    def response_unauthorized?
      !!transport_response && transport_response.code == 401
    end

    def response_has_digest_auth_challenge?
      !transport_response['www-authenticate'].nil? && transport_response['www-authenticate'].length > 0
    end

    def setup_digest_auth
      @raw_request.digest_auth(username, password, last_response)
    end

    def query_string(uri)
      query_string_parts = []
      query_string_parts << uri.query unless uri.query.nil?

      if options[:query].respond_to?(:to_hash)
        query_string_parts << normalize_query(options[:default_params].merge(options[:query].to_hash))
      else
        query_string_parts << normalize_query(options[:default_params]) unless options[:default_params].empty?
        query_string_parts << options[:query] unless options[:query].nil?
      end

      query_string_parts.reject!(&:empty?) unless query_string_parts == ['']
      query_string_parts.size > 0 ? query_string_parts.join('&') : nil
    end

    def assume_utf16_is_big_endian
      options[:assume_utf16_is_big_endian]
    end

    def handle_response(raw_body, &block)
      if response_redirects?
        handle_redirection(&block)
      else
        raw_body ||= transport_response.body

        body = decompress(raw_body, transport_response['content-encoding']) unless raw_body.nil?

        unless body.nil?
          body = encode_text(body, transport_response['content-type'])

          if decompress_content?
            transport_response.delete('content-encoding')
            raw_body = body
          end
        end

        Response.new(self, last_response, lambda { parse_response(body) }, body: raw_body)
      end
    end

    def handle_redirection(&block)
      options[:limit] -= 1
      if options[:logger]
        logger = HTTParty::Logger.build(options[:logger], options[:log_level], options[:log_format])
        logger.format(self, transport_response)
      end
      self.path       = transport_response['location']
      self.redirect   = true
      if transport_response.code == 303
        unless options[:maintain_method_across_redirects] && options[:resend_on_redirect]
          self.http_method = Net::HTTP::Get
        end
      elsif transport_response.code != 307 && transport_response.code != 308
        unless options[:maintain_method_across_redirects]
          self.http_method = Net::HTTP::Get
        end
      end
      if http_method == Net::HTTP::Get
        clear_body
      end
      capture_cookies(transport_response)
      perform(&block)
    end

    def handle_host_redirection
      check_duplicate_location_header
      redirect_path = options[:uri_adapter].parse(transport_response['location']).normalize
      return if redirect_path.relative? || path.host == redirect_path.host || uri.host == redirect_path.host
      @changed_hosts = true
    end

    def check_duplicate_location_header
      location = transport_response.get_fields('location')
      if location.is_a?(Array) && location.count > 1
        raise DuplicateLocationHeader.new(last_response)
      end
    end

    def send_authorization_header?
      !@changed_hosts
    end

    def response_redirects?
      return false if transport_response.code == 304

      transport_response.code.between?(300, 399) &&
        options[:follow_redirects] && transport_response.key?('location')
    end

    def parse_response(body)
      parser.call(body, format)
    end

    # Some Web Application Firewalls reject incoming GET requests that have a body
    # if we redirect, and the resulting verb is GET then we will clear the body that
    # may be left behind from the initiating request
    def clear_body
      options[:body] = nil
      @raw_request.body = nil
    end

    def capture_cookies(response)
      return unless response['Set-Cookie']
      cookies_hash = HTTParty::CookieHash.new
      cookies_hash.add_cookies(options[:headers].to_hash['Cookie']) if options[:headers] && options[:headers].to_hash['Cookie']
      response.get_fields('Set-Cookie').each { |cookie| cookies_hash.add_cookies(cookie) }

      options[:headers] ||= {}
      options[:headers]['Cookie'] = cookies_hash.to_cookie_string
    end

    # Uses the HTTP Content-Type header to determine the format of the
    # response It compares the MIME type returned to the types stored in the
    # SupportedFormats hash
    def format_from_mimetype(mimetype)
      if mimetype && parser.respond_to?(:format_from_mimetype)
        parser.format_from_mimetype(mimetype)
      end
    end

    def validate
      raise HTTParty::RedirectionTooDeep.new(last_response), 'HTTP redirects too deep' if options[:limit].to_i <= 0
      raise ArgumentError, 'only get, post, patch, put, delete, head, and options methods are supported' unless SupportedHTTPMethods.include?(http_method)
      raise ArgumentError, ':headers must be a hash' if options[:headers] && !options[:headers].respond_to?(:to_hash)
      raise ArgumentError, 'only one authentication method, :basic_auth or :digest_auth may be used at a time' if options[:basic_auth] && options[:digest_auth]
      raise ArgumentError, ':basic_auth must be a hash' if options[:basic_auth] && !options[:basic_auth].respond_to?(:to_hash)
      raise ArgumentError, ':digest_auth must be a hash' if options[:digest_auth] && !options[:digest_auth].respond_to?(:to_hash)
      raise ArgumentError, ':query must be hash if using HTTP Post' if post? && !options[:query].nil? && !options[:query].respond_to?(:to_hash)
    end

    def post?
      Net::HTTP::Post == http_method
    end

    def set_basic_auth_from_uri
      if path.userinfo
        username, password = path.userinfo.split(':')
        options[:basic_auth] = {username: username, password: password}
        @credentials_sent = true
      end
    end

    def decompress(body, encoding)
      Decompressor.new(body, encoding).decompress
    end

    def encode_text(text, content_type)
      TextEncoder.new(
        text,
        content_type: content_type,
        assume_utf16_is_big_endian: assume_utf16_is_big_endian
      ).call
    end

    def validate_uri_safety!(new_uri)
      return if options[:skip_uri_validation]

      configured_base_uri = options[:base_uri]
      return unless configured_base_uri

      normalized_base = options[:uri_adapter].parse(
        HTTParty.normalize_base_uri(configured_base_uri)
      )

      return if new_uri.host == normalized_base.host

      raise UnsafeURIError,
        "Requested URI '#{new_uri}' has host '#{new_uri.host}' but the " \
        "configured base_uri '#{normalized_base}' has host '#{normalized_base.host}'. " \
        "This request could send credentials to an unintended server."
    end
  end
end
