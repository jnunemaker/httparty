require 'net/http'
require 'net/https'
require 'uri'
require 'ostruct'
require 'rubygems'
require 'active_support'

directory = File.dirname(__FILE__)
$:.unshift(directory) unless $:.include?(directory) || $:.include?(File.expand_path(directory))

require 'httparty/request'

module ModuleLevelInheritableAttributes
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def mattr_inheritable(*args)
      @mattr_inheritable_attrs ||= [:mattr_inheritable_attrs]
      @mattr_inheritable_attrs += args
      args.each do |arg|
        module_eval %(
          class << self; attr_accessor :#{arg} end
        )
      end
      @mattr_inheritable_attrs
    end

    def inherited(subclass)
      @mattr_inheritable_attrs.each do |inheritable_attribute|
        instance_var = "@#{inheritable_attribute}" 
        subclass.instance_variable_set(instance_var, instance_variable_get(instance_var))
      end
    end
  end
end

module HTTParty
  class UnsupportedFormat < StandardError; end
  class RedirectionTooDeep < StandardError; end
  
  AllowedFormats = {:xml => 'text/xml', :json => 'application/json', :html => 'text/html'}
  
  def self.included(base)
    base.extend ClassMethods
    base.send :include, ModuleLevelInheritableAttributes
    base.send(:mattr_inheritable, :default_options)
    base.instance_variable_set("@default_options", {})
  end
  
  module ClassMethods    
    def default_options
      @default_options
    end

    #
    # Set an http proxy
    #
    #	class Twitter
    #	  include HTTParty
    #	  http_proxy 'http://myProxy', 1080
    # ....
    def http_proxy(addr=nil, port = nil)
      default_options[:http_proxyaddr] = addr
      default_options[:http_proxyport] = port
    end

    def base_uri(uri=nil)
      return default_options[:base_uri] unless uri
      default_options[:base_uri] = normalize_base_uri(uri)
    end

    def basic_auth(u, p)
      default_options[:basic_auth] = {:username => u, :password => p}
    end
    
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
    
    def get(path, options={})
      perform_request Net::HTTP::Get, path, options
    end

    def post(path, options={})
      perform_request Net::HTTP::Post, path, options
    end

    def put(path, options={})
      perform_request Net::HTTP::Put, path, options
    end

    def delete(path, options={})
      perform_request Net::HTTP::Delete, path, options
    end

    private
      def perform_request(http_method, path, options) #:nodoc:
        Request.new(http_method, path, default_options.merge(options)).perform
      end
    
      # Makes it so uri is sure to parse stuff like google.com without the http
      def normalize_base_uri(url) #:nodoc:
        use_ssl = (url =~ /^https/) || url.include?(':443')
        url.chop! if url.ends_with?('/')
        url.gsub!(/^https?:\/\//i, '')
        "http#{'s' if use_ssl}://#{url}"
      end
  end

  class Basement
    include HTTParty
  end
  
  def self.get(*args)
    Basement.get(*args)
  end
  
  def self.post(*args)
    Basement.post(*args)
  end

  def self.put(*args)
    Basement.put(*args)
  end

  def self.delete(*args)
    Basement.delete(*args)
  end

end
