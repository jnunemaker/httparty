require 'net/http'
require 'net/https'
require 'uri'
require 'ostruct'
require 'rubygems'
require 'active_support'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

dir = File.expand_path(File.join(File.dirname(__FILE__), 'httparty'))
require dir + '/core_ext'
  
module HTTParty
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def base_uri(base_uri=nil)
      return @base_uri unless base_uri
      # don't want this to ever end with /
      base_uri = base_uri.ends_with?('/') ? base_uri.chop : base_uri
      @base_uri = ensure_http(base_uri)
    end
    
    def basic_auth(u, p)
      @auth = {:username => u, :password => p}
    end
    
    def http
      if @http.blank?
        uri = URI.parse(base_uri)
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = (uri.port == 443)
        # so we can avoid ssl warnings
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      @http
    end
    
    def headers
      @headers ||= {}
    end
    
    def headers=(h)
      raise ArgumentError, 'Headers must be a hash' unless h.is_a?(Hash)
      headers.merge!(h)
    end
    
    def get(path, options={})
      send_request 'get', path, options
    end
    
    def post(path, options={})
      send_request 'post', path, options
    end
    
    def put(path, options={})
      send_request 'put', path, options
    end
    
    def delete(path, options={})
      send_request 'delete', path, options
    end
    
    def format(f=nil)
      @format = f.to_s
    end
    
    private
      # options can be any or all of:
      #   query   => hash of keys/values to be converted to query string
      #   body    => string for raw post data
      #   headers => hash of headers to send request with
      def send_request(method, path, options={})
        # we always want path that begins with /
        path = path.starts_with?('/') ? path : "/#{path}"
        @format      = format_from_path(path) unless @format
        uri          = URI.parse("#{base_uri}#{path}")
        uri.query    = options[:query].to_query unless options[:query].blank?
        klass        = Net::HTTP.const_get method.to_s.downcase.capitalize
        request      = klass.new(uri.request_uri)
        request.body = options[:body] unless options[:body].blank?
        request.initialize_http_header headers.merge(options[:headers] || {})
        request.basic_auth(@auth[:username], @auth[:password]) if @auth
        @response    = http.start() { |conn| conn.request(request) }
        parse(@response.body)
      end
      
      def parse(body)
        case @format
        when 'xml'
          Hash.from_xml(body)
        when 'json'
          ActiveSupport::JSON.decode(body)
        else
          body
        end
      end
    
      # Makes it so uri is sure to parse stuff like google.com with the http
      def ensure_http(str)
        str =~ /^https?:\/\// ? str : "http#{'s' if str.include?(':443')}://#{str}"
      end
      
      # Returns a format that we can handle from the path if possible. 
      # Just does simple pattern matching on file extention:
      #   /foobar.xml => 'xml'
      #   /foobar.json => 'json'
      def format_from_path(path)
        return case path
        when /\.xml$/
          'xml'
        when /\.json$/
          'json'
        else
          nil
        end
      end
  end
end