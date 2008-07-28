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
  
  class UnsupportedFormat < StandardError; end
  
  AllowedFormats = %w[xml json]
  
  module ClassMethods    
    def base_uri(base_uri=nil)
      return @base_uri unless base_uri
      # don't want this to ever end with /
      base_uri = base_uri.ends_with?('/') ? base_uri.chop : base_uri
      @base_uri = normalize_base_uri(base_uri)
    end
    
    def basic_auth(u, p)
      @auth = {:username => u, :password => p}
    end
    
    def default_params(h={})
      raise ArgumentError, 'Default params must be a hash' unless h.is_a?(Hash)
      @default_params ||= {}
      return @default_params if h.blank?
      @default_params.merge!(h)
    end

    def headers(h={})
      raise ArgumentError, 'Headers must be a hash' unless h.is_a?(Hash)
      @headers ||= {}
      return @headers if h.blank?
      @headers.merge!(h)
    end
    
    def format(f)
      f = f.to_s
      raise UnsupportedFormat, "Must be one of: #{AllowedFormats.join(', ')}" unless AllowedFormats.include?(f)
      @format = f
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
    
    # TODO: spec out this
    def get(path, options={})
      send_request 'get', path, options
    end

    # TODO: spec out this    
    def post(path, options={})
      send_request 'post', path, options
    end

    # TODO: spec out this    
    def put(path, options={})
      send_request 'put', path, options
    end

    # TODO: spec out this    
    def delete(path, options={})
      send_request 'delete', path, options
    end
    
    private
      # options can be any or all of:
      #   query   => hash of keys/values to be converted to query string
      #   body    => string for raw post data
      #   headers => hash of headers to send request with
      def send_request(method, path, options={})
        raise ArgumentError, 'only get, post, put and delete methods are supported' unless %w[get post put delete].include?(method.to_s)
        raise ArgumentError, ':query must be a hash' if options[:query] && !options[:query].is_a?(Hash)
        raise ArgumentError, ':headers must be a hash' if options[:headers] && !options[:headers].is_a?(Hash)
        # we always want path that begins with /
        path         = path.starts_with?('/') ? path : "/#{path}"
        @format    ||= format_from_path(path)
        uri          = URI.parse("#{base_uri}#{path}")
        uri.query    = default_params.merge(options[:query] || {}).to_query
        klass        = Net::HTTP.const_get method.to_s.downcase.capitalize
        request      = klass.new(uri.request_uri)
        request.body = options[:body] unless options[:body].blank?
        request.initialize_http_header headers.merge(options[:headers] || {})
        request.basic_auth(@auth[:username], @auth[:password]) if @auth
        response     = http.start() { |conn| conn.request(request) }
        parse_response(response.body)
      end
      
      def parse_response(body)
        case @format
        when 'xml'
          Hash.from_xml(body)
        when 'json'
          ActiveSupport::JSON.decode(body)
        else
          # just return the response if no format 
          body
        end
      end
    
      # Makes it so uri is sure to parse stuff like google.com with the http
      def normalize_base_uri(str)
        str =~ /^https?:\/\// ? str : "http#{'s' if str.include?(':443')}://#{str}"
      end
      
      # Returns a format that we can handle from the path if possible. 
      # Just does simple pattern matching on file extention:
      #   /foobar.xml => 'xml'
      #   /foobar.json => 'json'
      def format_from_path(path)
        ext = File.extname(path)[1..-1]
        !ext.blank? && AllowedFormats.include?(ext) ? ext : nil
      end
  end
end