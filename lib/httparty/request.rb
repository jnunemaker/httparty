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
      Net::HTTP::Copy
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

    attr_accessor :http_method, :options, :last_response, :redirect, :last_uri
    attr_reader :path

    def initialize(http_method, path, o = {})
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
      elsif String.try_convert(uri)
        uri_adapter.parse uri
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
      if redirect && path.relative? && path.path[0] != "/"
        last_uri_host = @last_uri.path.gsub(/[^\/]+$/, "")

        path.path = "/#{path.path}" if last_uri_host[-1] != "/"
        path.path = last_uri_host + path.path
      end

      new_uri = path.relative? ? options[:uri_adapter].parse("#{base_uri}#{path}") : path.clone

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
        base_uri += ":#{@last_uri.port}" if @last_uri.port != 80
        base_uri
      else
        options[:base_uri]
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

      self.last_response = http.request(@raw_request) do |http_response|
        if block
          chunks = []

          http_response.read_body do |fragment|
            chunks << fragment unless options[:stream_body]
            block.call(fragment)
          end

          chunked_body = chunks.join
        end
      end

      handle_deflation unless http_method == Net::HTTP::Head
      handle_response(chunked_body, &block)
    end

    def raw_body
      @raw_request.body
    end

    private

    def http
      connection_adapter.call(uri, options)
    end

    def body
      options[:body].respond_to?(:to_hash) ? normalize_query(options[:body]) : options[:body]
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
      @raw_request = http_method.new(request_uri(uri))
      @raw_request.body = body if body
      @raw_request.body_stream = options[:body_stream] if options[:body_stream]
      @raw_request.initialize_http_header(options[:headers].to_hash) if options[:headers].respond_to?(:to_hash)
      @raw_request.basic_auth(username, password) if options[:basic_auth]
      setup_digest_auth if options[:digest_auth]
    end

    def setup_digest_auth
      auth_request = http_method.new(uri.request_uri)
      auth_request.initialize_http_header(options[:headers].to_hash) if options[:headers].respond_to?(:to_hash)
      res = http.request(auth_request)

      if !res['www-authenticate'].nil? && res['www-authenticate'].length > 0
        @raw_request.digest_auth(username, password, res)
      end
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

      query_string_parts.reject!(&:empty?) unless query_string_parts == [""]
      query_string_parts.size > 0 ? query_string_parts.join('&') : nil
    end

    def get_charset
      content_type = last_response["content-type"]
      if content_type.nil?
        return nil
      end

      if content_type =~ /;\s*charset\s*=\s*([^=,;"\s]+)/i
        return $1
      end

      if content_type =~ /;\s*charset\s*=\s*"((\\.|[^\\"])+)"/i
        return $1.gsub(/\\(.)/, '\1')
      end

      nil
    end

    def encode_with_ruby_encoding(body, charset)
      encoding = Encoding.find(charset)
      body.force_encoding(encoding)
    rescue
      body
    end

    def assume_utf16_is_big_endian
      options[:assume_utf16_is_big_endian]
    end

    def encode_utf_16(body)
      if body.bytesize >= 2
        if body.getbyte(0) == 0xFF && body.getbyte(1) == 0xFE
          return body.force_encoding("UTF-16LE")
        elsif body.getbyte(0) == 0xFE && body.getbyte(1) == 0xFF
          return body.force_encoding("UTF-16BE")
        end
      end

      if assume_utf16_is_big_endian
        body.force_encoding("UTF-16BE")
      else
        body.force_encoding("UTF-16LE")
      end
    end

    def _encode_body(body)
      charset = get_charset

      if charset.nil?
        return body
      end

      if "utf-16".casecmp(charset) == 0
        encode_utf_16(body)
      else
        encode_with_ruby_encoding(body, charset)
      end
    end

    def encode_body(body)
      if "".respond_to?(:encoding)
        _encode_body(body)
      else
        body
      end
    end

    def handle_response(body, &block)
      if response_redirects?
        options[:limit] -= 1
        if options[:logger]
          logger = HTTParty::Logger.build(options[:logger], options[:log_level], options[:log_format])
          logger.format(self, last_response)
        end
        self.path = last_response['location']
        self.redirect = true
        if last_response.class == Net::HTTPSeeOther
          unless options[:maintain_method_across_redirects] && options[:resend_on_redirect]
            self.http_method = Net::HTTP::Get
          end
        elsif last_response.code != '307' && last_response.code != '308'
          unless options[:maintain_method_across_redirects]
            self.http_method = Net::HTTP::Get
          end
        end
        capture_cookies(last_response)
        perform(&block)
      else
        body ||= last_response.body
        body = encode_body(body)
        Response.new(self, last_response, lambda { parse_response(body) }, body: body)
      end
    end

    # Inspired by Ruby 1.9
    def handle_deflation
      case last_response["content-encoding"]
      when "gzip", "x-gzip"
        body_io = StringIO.new(last_response.body)
        last_response.body.replace Zlib::GzipReader.new(body_io).read
        last_response.delete('content-encoding')
      when "deflate"
        last_response.body.replace Zlib::Inflate.inflate(last_response.body)
        last_response.delete('content-encoding')
      end
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
      end
    end
  end
end
