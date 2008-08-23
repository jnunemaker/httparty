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
  class UnsupportedFormat < StandardError; end
  
  def self.included(base)
    base.extend ClassMethods
  end
  
  AllowedFormats = {:xml => 'text/xml', :json => 'application/json'}
  
  module ClassMethods    
    #
    # Set an http proxy
    #
    #	class Twitter
    #	  include HTTParty
    #	  http_proxy http://myProxy, 1080
    # ....
    def http_proxy(addr=nil, port = nil)
	   @http_proxyaddr = addr
	   @http_proxyport = port
    end

    def base_uri(base_uri=nil)
      return @base_uri unless base_uri
      # don't want this to ever end with /
      base_uri = base_uri.ends_with?('/') ? base_uri.chop : base_uri
      @base_uri = normalize_base_uri(base_uri)
    end
    
    # Warning: This is not thread safe most likely and
    # only works if you use one set of credentials. I
    # leave it because it is convenient on some occasions.
    def basic_auth(u, p)
      @auth = {:username => u, :password => p}
    end
    
    # Updates the default query string parameters
    # that should be appended to each request.
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
      raise UnsupportedFormat, "Must be one of: #{AllowedFormats.keys.join(', ')}" unless AllowedFormats.key?(f)
      @format = f
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
      def http(uri) #:nodoc:
        if @http.blank?
          @http = Net::HTTP.new(uri.host, uri.port, @http_proxyaddr, @http_proxyport)
          @http.use_ssl = (uri.port == 443)
          # so we can avoid ssl warnings
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        @http
      end
      
      # FIXME: this method is doing way to much and needs to be split up
      # options can be any or all of:
      #   query       => hash of keys/values or a query string (foo=bar&baz=poo)
      #   body        => hash of keys/values or a query string (foo=bar&baz=poo)
      #   headers     => hash of headers to send request with
      #   basic_auth  => :username and :password to use as basic http authentication (overrides @auth class instance variable)
      # Raises exception Net::XXX (http error code) if an http error occured
      def send_request(method, path, options={}) #:nodoc:
        raise ArgumentError, 'only get, post, put and delete methods are supported' unless %w[get post put delete].include?(method.to_s)
        raise ArgumentError, ':headers must be a hash' if options[:headers] && !options[:headers].is_a?(Hash)
        raise ArgumentError, ':basic_auth must be a hash' if options[:basic_auth] && !options[:basic_auth].is_a?(Hash)
        uri            = URI.parse("#{base_uri}#{path}")
        existing_query = uri.query ? "#{uri.query}&" : ''
        uri.query      = if options[:query].blank?
          existing_query + default_params.to_query
        else
          existing_query + (options[:query].is_a?(Hash) ? default_params.merge(options[:query]).to_query : options[:query])
        end
        klass          = Net::HTTP.const_get method.to_s.downcase.capitalize
        request        = klass.new(uri.request_uri)
        request.body   = options[:body].is_a?(Hash) ? options[:body].to_query : options[:body] unless options[:body].blank?
        basic_auth     = options.delete(:basic_auth) || @auth
        request.initialize_http_header headers.merge(options[:headers] || {})
        # note to self: self, do not put basic auth above headers because it removes basic auth
        request.basic_auth(basic_auth[:username], basic_auth[:password]) if basic_auth
        response       = http(uri).request(request)
        @format      ||= format_from_mimetype(response['content-type'])
        
        case response
        when Net::HTTPSuccess
          parse_response(response.body)
        else
          response.instance_eval { class << self; attr_accessor :body_parsed; end }
          begin; response.body_parsed = parse_response(response.body); rescue; end
          response.error! # raises  exception corresponding to http error Net::XXX
        end

      end
      
      def parse_response(body) #:nodoc:
        case @format
        when :xml
          Hash.from_xml(body)
        when :json
          ActiveSupport::JSON.decode(body)
        else
          # just return the response if no format 
          body
        end
      end
    
      # Makes it so uri is sure to parse stuff like google.com with the http
      def normalize_base_uri(str) #:nodoc:
        str =~ /^https?:\/\// ? str : "http#{'s' if str.include?(':443')}://#{str}"
      end
      
      # Uses the HTTP Content-Type header to determine the format of the response
      # It compares the MIME type returned to the types stored in the AllowedFormats hash
      def format_from_mimetype(mimetype) #:nodoc:
        AllowedFormats.each { |k, v| return k if mimetype.include?(v) }
      end
  end
end