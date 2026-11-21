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
    DEFAULT_PORTS = { 'http' => 80, 'https' => 443 }.freeze
    # Headers that describe a request body, and so are dropped along with it
    CONTENT_HEADERS = %w[content-encoding content-language content-length content-location content-type transfer-encoding].freeze

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
      @cross_origin_redirect = false
      @credentials_sent = false

      self.http_method = http_method
      self.options = {
        limit: o.delete(:no_follow) ? 1 : 5,
        assume_utf16_is_big_endian: true,
        default_params: {},
        follow_redirects: true,
        parser: Parser,
        uri_adapter: URI,
        connection_adapter: ConnectionAdapter
      }.merge(o)
      self.path = path
      set_basic_auth_from_uri
    end

    def path=(uri)
      uri_adapter = options[:uri_adapter]

      @path = if uri.is_a?(uri_adapter)
        uri
      elsif (uri_str = String.try_convert(uri))
        # Normalizing an empty path ("", "?query" or "#fragment") with the
        # default URI adapter turns it into "/", which appends an unwanted
        # trailing slash to the base_uri path (breaking e.g. SOAP endpoints).
        # Such a reference means the base_uri itself (RFC 3986 section 5.2.2),
        # so leave it alone and let the uri adapter normalize everything else.
        # See https://github.com/jnunemaker/httparty/issues/742
        parsed_uri = uri_adapter.parse(uri_str)
        empty_path_reference?(parsed_uri) ? parsed_uri : parsed_uri.normalize
      else
        raise ArgumentError,
          "bad argument (expected #{uri_adapter} object or URI string)"
      end
    end

    def request_uri(uri)
      if uri.respond_to? :request_uri
        uri.request_uri
      else
        uri.query ? "#{uri.path}?#{uri.query}" : uri.path
      end
    end

    def uri
      # Resolve a relative redirect Location ("baz", "../baz", "?page=2", "")
      # against the URL that redirected (RFC 3986 section 5.2). Keep it as an
      # absolute path so later calls resolve it to the same URL. A Location
      # with a host is used as given below.
      if redirect && path.relative? && path.host.nil?
        @path = options[:uri_adapter].parse(request_uri((@last_uri + path).normalize))
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
      options[:format] || (format_from_mimetype(last_response['content-type']) if last_response)
    end

    def parser
      options[:parser]
    end

    def connection_adapter
      options[:connection_adapter]
    end

    def perform(&block)
      validate
      setup_raw_request
      chunked_body = nil
      current_http = http

      begin
        self.last_response = current_http.request(@raw_request) do |http_response|
          if block
            chunks = []

            http_response.read_body do |fragment|
              encoded_fragment = encode_text(fragment, http_response['content-type'])
              chunks << encoded_fragment if !options[:stream_body]
              block.call ResponseFragment.new(encoded_fragment, http_response, current_http)
            end

            chunked_body = chunks.join
          end
        end

        handle_host_redirection if response_redirects?
        result = handle_unauthorized(&block)
        result ||= handle_response(chunked_body, &block)
        result
      rescue *COMMON_NETWORK_ERRORS => e
        raise options[:foul] ? HTTParty::NetworkError.new("#{e.class}: #{e.message}") : e
      end
    end

    def handle_unauthorized(&block)
      return unless digest_auth? && send_authorization_header? && response_unauthorized? && response_has_digest_auth_challenge?
      return if @credentials_sent
      @credentials_sent = true
      perform(&block)
    end

    def raw_body
      @raw_request.body
    end

    def _dump(_level)
      opts = options.reject { |key, value| value.is_a?(Proc) || %i[logger debug_output].include?(key) }
      Marshal.dump([http_method, path, opts, last_response, @last_uri, @raw_request])
    end

    private

    def http
      connection_adapter.call(uri, options)
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
        unless send_authorization_header?
          # Header names are case-insensitive, and reject leaves the caller's hash alone
          headers_hash = headers_hash.reject { |name, _| name.to_s.casecmp?('authorization') }
        end
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
      setup_digest_auth if digest_auth? && send_authorization_header? && response_unauthorized? && response_has_digest_auth_challenge?
    end

    def digest_auth?
      !!options[:digest_auth]
    end

    def decompress_content?
      !options[:skip_decompression]
    end

    def response_unauthorized?
      !!last_response && last_response.code == '401'
    end

    def response_has_digest_auth_challenge?
      !last_response['www-authenticate'].nil? && last_response['www-authenticate'].length > 0
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
        raw_body ||= last_response.body

        body = decompress(raw_body, last_response['content-encoding']) unless raw_body.nil?

        unless body.nil?
          body = encode_text(body, last_response['content-type'])

          if decompress_content?
            last_response.delete('content-encoding')
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
        logger.format(self, last_response)
      end
      # A relative Location is resolved against the current URL in #uri, so
      # it isn't normalized first: Addressable would drop the "../" in it.
      location        = options[:uri_adapter].parse(last_response['location'])
      self.path       = location.relative? && location.host.nil? ? location : location.normalize
      self.redirect   = true
      if last_response.class == Net::HTTPSeeOther
        # A 303 turns the request into a GET, but a HEAD stays a HEAD (RFC 9110)
        unless options[:maintain_method_across_redirects] && (options[:resend_on_redirect] || http_method == Net::HTTP::Head)
          self.http_method = Net::HTTP::Get
        end
      elsif last_response.code != '307' && last_response.code != '308'
        unless options[:maintain_method_across_redirects]
          self.http_method = Net::HTTP::Get
        end
      end
      if http_method == Net::HTTP::Get
        clear_body
      end
      # Cookies stay with the origin they came from. HTTParty doesn't track the
      # Set-Cookie Domain attribute, so a redirect to another origin gets none
      # of them; that origin's own Set-Cookie cookies are collected from here on.
      @cross_origin_redirect ? drop_cookies : capture_cookies(last_response)
      perform(&block)
    end

    def handle_host_redirection
      check_duplicate_location_header
      redirect_path = options[:uri_adapter].parse(last_response['location']).normalize
      # A Location without a host ("/x", "../x", "?a") stays on the same origin.
      # A scheme-relative one ("//other.example.com/x") has a host to compare.
      @cross_origin_redirect = !(redirect_path.relative? && redirect_path.host.nil?) &&
        cross_origin_redirect?(@last_uri, redirect_path)
      @changed_hosts = true if @cross_origin_redirect
    end

    # Credentials only follow a redirect to the same scheme, host and port, as
    # in curl and Python requests. An http -> https upgrade on the default
    # ports keeps them, and once dropped they stay dropped for the request.
    def cross_origin_redirect?(from, to)
      return true unless from.host.to_s.casecmp?(to.host.to_s)

      to_scheme = (to.scheme || from.scheme).to_s.downcase
      from_scheme = from.scheme.to_s.downcase
      from_port = from.port || DEFAULT_PORTS[from_scheme]
      to_port = to.port || DEFAULT_PORTS[to_scheme]
      return false if from_scheme == to_scheme && from_port == to_port

      !(from_scheme == 'http' && from_port == 80 && to_scheme == 'https' && to_port == 443)
    end

    def check_duplicate_location_header
      location = last_response.get_fields('location')
      if location.is_a?(Array) && location.count > 1
        raise DuplicateLocationHeader.new(last_response)
      end
    end

    def send_authorization_header?
      !@changed_hosts
    end

    def response_redirects?
      case last_response
      when Net::HTTPNotModified # 304
        false
      when Net::HTTPRedirection
        options[:follow_redirects] && last_response.key?('location')
      end
    end

    def parse_response(body)
      parser.call(body, format)
    end

    # Some Web Application Firewalls reject incoming GET requests that have a body
    # if we redirect, and the resulting verb is GET then we will clear the body (or
    # body_stream) that may be left behind from the initiating request, along with
    # the header fields that described it (RFC 9110, section 15.4)
    def clear_body
      options[:body] = nil
      options[:body_stream] = nil
      @raw_request.body = nil
      return unless options[:headers].respond_to?(:to_hash)

      options[:headers] = options[:headers].to_hash.reject do |name, _|
        CONTENT_HEADERS.include?(name.to_s.downcase)
      end
    end

    def capture_cookies(response)
      return unless response['Set-Cookie']
      headers = options[:headers].respond_to?(:to_hash) ? options[:headers].to_hash : {}
      # Class and request cookies are stored as "cookie", so match any case
      cookie_names = headers.keys.select { |name| name.to_s.casecmp?('cookie') }
      cookies_hash = HTTParty::CookieHash.new
      cookie_names.each { |name| cookies_hash.add_cookies(headers[name]) }
      response.get_fields('Set-Cookie').each { |cookie| cookies_hash.add_cookies(cookie) }

      options[:headers] = headers.reject { |name, _| cookie_names.include?(name) }
                                 .merge('Cookie' => cookies_hash.to_cookie_string)
    end

    def drop_cookies
      return unless options[:headers].respond_to?(:to_hash)
      options[:headers] = options[:headers].to_hash.reject { |name, _| name.to_s.casecmp?('cookie') }
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
      raise ArgumentError, "only #{SupportedHTTPMethods.map { |m| m::METHOD.downcase }.join(', ')} methods are supported" unless SupportedHTTPMethods.include?(http_method)
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

    # A reference with no scheme, host or path ("", "?query" or "#fragment")
    # refers to the base URI itself (RFC 3986 section 5.2.2).
    def empty_path_reference?(uri)
      uri.scheme.nil? && uri.host.nil? && uri.path.to_s.empty?
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
