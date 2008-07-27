require 'net/http'
require 'net/https'
require 'uri'
require 'rubygems'
require 'active_support'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Web
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def base_uri(base_uri=nil)
      return @base_uri unless base_uri
      @base_uri = ensure_http(base_uri)
    end
    
    def basic_auth(u, p)
      @auth = {:username => u, :password => p}
    end
    
    def http(&block)
      if @http.blank?
        uri = URI.parse(base_uri)
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = (uri.port == 443)
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
    
    def response
      @response
    end
    
    private
      # options can be any or all of:
      #   query   => hash of keys/values to be converted to query string
      #   body    => string for raw post data
      #   headers => hash of headers to send request with
      def send_request(method, path, options={})
        uri          = URI.join(base_uri, path)
        uri.query    = options[:query].to_query unless options[:query].blank?
        klass        = Net::HTTP.const_get method.to_s.downcase.capitalize
        request      = klass.new(uri.request_uri)
        request.body = options[:body] unless options[:body].blank?
        request.initialize_http_header headers.merge(options[:headers] || {})
        request.basic_auth(@auth[:username], @auth[:password]) if @auth
        @response = http.start() { |conn| conn.request(request) }
        @response.body
      end
    
      # Makes it so uri is sure to parse stuff like google.com with the http
      def ensure_http(str)
        str =~ /^https?:\/\// ? str : "http#{'s' if str.include?(':443')}://#{str}"
      end
  end
end

dir = File.expand_path(File.join(File.dirname(__FILE__), 'web'))
require dir + '/entity'