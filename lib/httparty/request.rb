require 'uri'

module HTTParty
  class Request #:nodoc:
    SupportedHTTPMethods = [Net::HTTP::Get, Net::HTTP::Post, Net::HTTP::Put, Net::HTTP::Delete]
    
    attr_accessor :http_method, :path, :options
    
    def initialize(http_method, path, o={})
      self.http_method = http_method
      self.path = path
      self.options = {
        :limit => o.delete(:no_follow) ? 0 : 5, 
        :default_params => {},
      }.merge(o)
    end

    def path=(uri)
      @path = URI.parse(uri)
    end
    
    def uri
      new_uri = path.relative? ? URI.parse("#{options[:base_uri]}#{path}") : path
      
      # avoid double query string on redirects [#12]
      unless @redirect
        new_uri.query = query_string(new_uri)
      end
      
      new_uri
    end
    
    def format
      options[:format]
    end
    
    def perform
      validate
      setup_raw_request
      handle_response(get_response)
    end

    private

      def http
        http = Net::HTTP.new(uri.host, uri.port, options[:http_proxyaddr], options[:http_proxyport])
        http.use_ssl = (uri.port == 443)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        if options[:timeout] && options[:timeout].is_a?(Integer)
          http.open_timeout = options[:timeout]
          http.read_timeout = options[:timeout]
        end
        http
      end

      def body
        options[:body].is_a?(Hash) ? options[:body].to_params : options[:body]
      end
      
      def username
        options[:basic_auth][:username]
      end
      
      def password
        options[:basic_auth][:password]
      end

      def setup_raw_request
        @raw_request = http_method.new(uri.request_uri)
        @raw_request.body = body if body
        @raw_request.initialize_http_header(options[:headers])
        @raw_request.basic_auth(username, password) if options[:basic_auth]
      end

      def perform_actual_request
        http.request(@raw_request)
      end

      def get_response
        response = perform_actual_request
        options[:format] ||= format_from_mimetype(response['content-type'])
        response
      end
      
      def query_string(uri)
        query_string_parts = []
        query_string_parts << uri.query unless uri.query.nil?

        if options[:query].is_a?(Hash)
          query_string_parts << options[:default_params].merge(options[:query]).to_params
        else
          query_string_parts << options[:default_params].to_params unless options[:default_params].nil?
          query_string_parts << options[:query] unless options[:query].nil?
        end
        
        query_string_parts.size > 0 ? query_string_parts.join('&') : nil
      end
      
      # Raises exception Net::XXX (http error code) if an http error occured
      def handle_response(response)
        case response
          when Net::HTTPRedirection
            options[:limit] -= 1
            self.path = response['location']
            @redirect = true
            self.http_method = Net::HTTP::Get
            capture_cookies(response)
            perform
          else
            parsed_response = parse_response(response.body)
            Response.new(parsed_response, response.body, response.code, response.message, response.to_hash)
          end
      end
      
      # HTTParty.const_get((self.format.to_s || 'text').capitalize)
      def parse_response(body)
        return nil if body.nil? or body.empty?
        if options[:parser].blank?
          case format
            when :xml
              Crack::XML.parse(body)
            when :json
              Crack::JSON.parse(body)
            when :yaml
              YAML::load(body)
            else
              body
            end
        else
          if options[:parser].is_a?(Proc)
            options[:parser].call(body)
          else
            body
          end
        end
      end
            
      def capture_cookies(response)
        return unless response['Set-Cookie']
        cookies_hash = HTTParty::CookieHash.new()
        cookies_hash.add_cookies(options[:headers]['Cookie']) if options[:headers] && options[:headers]['Cookie']
        cookies_hash.add_cookies(response['Set-Cookie'])
        options[:headers] ||= {}
        options[:headers]['Cookie'] = cookies_hash.to_cookie_string
      end
      
      def capture_cookies(response)
        return unless response['Set-Cookie']
        cookies_hash = HTTParty::CookieHash.new()
        cookies_hash.add_cookies(options[:headers]['Cookie']) if options[:headers] && options[:headers]['Cookie']
        cookies_hash.add_cookies(response['Set-Cookie'])
        options[:headers] ||= {}
        options[:headers]['Cookie'] = cookies_hash.to_cookie_string
      end
  
      # Uses the HTTP Content-Type header to determine the format of the response
      # It compares the MIME type returned to the types stored in the AllowedFormats hash
      def format_from_mimetype(mimetype)
        return nil if mimetype.nil?
        AllowedFormats.each { |k, v| return v if mimetype.include?(k) }
      end
      
      def validate
        raise HTTParty::RedirectionTooDeep, 'HTTP redirects too deep' if options[:limit].to_i <= 0
        raise ArgumentError, 'only get, post, put and delete methods are supported' unless SupportedHTTPMethods.include?(http_method)
        raise ArgumentError, ':headers must be a hash' if options[:headers] && !options[:headers].is_a?(Hash)
        raise ArgumentError, ':basic_auth must be a hash' if options[:basic_auth] && !options[:basic_auth].is_a?(Hash)
        raise ArgumentError, ':query must be hash if using HTTP Post' if post? && !options[:query].nil? && !options[:query].is_a?(Hash)
      end
      
      def post?
        Net::HTTP::Post == http_method
      end
  end
end
