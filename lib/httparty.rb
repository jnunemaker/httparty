require 'net/http'
require 'net/https'
require 'uri'
require 'ostruct'
require 'rubygems'
require 'active_support'

directory = File.dirname(__FILE__)
$:.unshift(directory) unless $:.include?(directory) || $:.include?(File.expand_path(directory))

require 'httparty/request'

module HTTParty
  class UnsupportedFormat < StandardError; end
  class RedirectionTooDeep < StandardError; end

  AllowedFormats = {:xml => 'text/xml', :json => 'application/json'}
  
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods    
    def default_options
      @@default_options ||= {}
    end

    #
    # Set an http proxy
    #
    #	class Twitter
    #	  include HTTParty
    #	  http_proxy http://myProxy, 1080
    # ....
    def http_proxy(addr=nil, port = nil)
      default_options[:http_proxyaddr] = addr
      default_options[:http_proxyport] = port
    end

    def base_uri(uri=nil)
      return default_options[:base_uri] unless uri
      default_options[:base_uri] = normalize_base_uri(uri)
    end

    # Warning: This is not thread safe most likely and
    # only works if you use one set of credentials. I
    # leave it because it is convenient on some occasions.
    def basic_auth(u, p)
      default_options[:basic_auth] = {:username => u, :password => p}
    end
    
    # Updates the default query string parameters
    # that should be appended to each request.
    def default_params(h={})
      raise ArgumentError, 'Default params must be a hash' unless h.is_a?(Hash)
      default_options[:default_params] ||= {}
      default_options[:default_params].merge!(h)
    end

    def headers(h={})
      raise ArgumentError, 'Headers must be a hash' unless h.is_a?(Hash)
      default_options[:headers] ||= {}
      default_options[:headers].merge!(h)
    end
    
    def format(f)
      raise UnsupportedFormat, "Must be one of: #{AllowedFormats.keys.join(', ')}" unless AllowedFormats.key?(f)
      default_options[:format] = f
    end
    
    
    # TODO: spec out this
    def get(path, options={})
      perform_request Net::HTTP::Get, path, options
    end

    # TODO: spec out this    
    def post(path, options={})
      perform_request Net::HTTP::Post, path, options
    end

    # TODO: spec out this    
    def put(path, options={})
      perform_request Net::HTTP::Put, path, options
    end

    # TODO: spec out this    
    def delete(path, options={})
      perform_request Net::HTTP::Delete, path, options
    end

    private

      def perform_request(http_method, path, options)
        Request.perform_request(http_method, path, default_options.merge(options))
      end
    
      # Makes it so uri is sure to parse stuff like google.com with the http
      def normalize_base_uri(url) #:nodoc:
        use_ssl = (url =~ /^https/) || url.include?(':443')
        url.chop! if url.ends_with?('/')
        url.gsub!(/^https?:\/\//i, '')
        "http#{'s' if use_ssl}://#{url}"
      end
  end
end
