module HTTParty
  class Request
    SupportedHTTPMethods = [Net::HTTP::Get, Net::HTTP::Post, Net::HTTP::Put, Net::HTTP::Delete]

    def self.perform_request(http_method, path, options={})
      new(http_method, path, options).perform
    end

    attr_accessor :http_method, :path, :options
    
    def initialize(http_method, path, options={})
      self.http_method = http_method
      self.path = path
      self.options = {
        :limit => options.delete(:no_follow) ? 0 : 5, 
        :default_params => {},
      }.merge(options.dup)
    end

    def path=(uri)
      @path = URI.parse(uri)
    end

    # FIXME: this method is doing way to much and needs to be split up
    # options can be any or all of:
    #   query       => hash of keys/values or a query string (foo=bar&baz=poo)
    #   body        => hash of keys/values or a query string (foo=bar&baz=poo)
    #   headers     => hash of headers to send request with
    #   basic_auth  => :username and :password to use as basic http authentication (overrides basic_auth setting)
    # Raises exception Net::XXX (http error code) if an http error occured
    def perform #:nodoc:
      raise HTTParty::RedirectionTooDeep, 'HTTP redirects too deep' if options[:limit].to_i <= 0
      raise ArgumentError, 'only get, post, put and delete methods are supported' unless SupportedHTTPMethods.include?(http_method)
      raise ArgumentError, ':headers must be a hash' if options[:headers] && !options[:headers].is_a?(Hash)
      raise ArgumentError, ':basic_auth must be a hash' if options[:basic_auth] && !options[:basic_auth].is_a?(Hash)
      
      uri = path.relative? ? URI.parse("#{options[:base_uri]}#{path}") : path
      
      query_string_parts = []
      query_string_parts << uri.query unless uri.query.blank?
      
      if options[:query].is_a?(Hash)
        query_string_parts << options[:default_params].merge(options[:query]).to_query
      else
        query_string_parts << options[:default_params].to_query unless options[:default_params].blank?
        query_string_parts << options[:query] unless options[:query].blank?
      end
      
      uri.query = query_string_parts.join('&') if query_string_parts.size > 0
      
      request        = http_method.new(uri.request_uri)
      request.body   = options[:body].is_a?(Hash) ? options[:body].to_query : options[:body] unless options[:body].blank?
      request.initialize_http_header options[:headers]
      request.basic_auth(options[:basic_auth][:username], options[:basic_auth][:password]) if options[:basic_auth]
      response       = http(uri).request(request)
      
      options[:format] ||= format_from_mimetype(response['content-type'])
      
      case response
      when Net::HTTPSuccess
        parse_response(response.body)
      when Net::HTTPRedirection
        options[:limit] -= 1
        self.path = response['location']
        perform
      else
        response.instance_eval { class << self; attr_accessor :body_parsed; end }
        begin; response.body_parsed = parse_response(response.body); rescue; end
        response.error! # raises  exception corresponding to http error Net::XXX
      end
    end

    private

      def http(uri) #:nodoc:
        http = Net::HTTP.new(uri.host, uri.port, options[:http_proxyaddr], options[:http_proxyport])
        http.use_ssl = (uri.port == 443)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http
      end
      
      def parse_response(body) #:nodoc:
        return nil if body.nil? or body.empty?
        case options[:format]
        when :xml
          Hash.from_xml(body)
        when :json
          ActiveSupport::JSON.decode(body)
        else
          body
        end
      end
  
      # Uses the HTTP Content-Type header to determine the format of the response
      # It compares the MIME type returned to the types stored in the AllowedFormats hash
      def format_from_mimetype(mimetype) #:nodoc:
        AllowedFormats.each { |k, v| return k if mimetype.include?(v) }
      end
  end
end
