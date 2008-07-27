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
      if base_uri
        @base_uri = URI.parse(ensure_http(base_uri))
      else
        @base_uri
      end
    end
    
    def http
      if @http.blank?
        @http = Net::HTTP.new(base_uri.host, base_uri.port)
        @http.use_ssl = (base_uri.port == 443)
      end
      @http
    end
    
    private
      # Makes it so uri is sure to parse stuff like google.com with the http
      def ensure_http(str)
        str =~ /^https?:\/\// ? str : "http#{'s' if str.include?(':443')}://#{str}"
      end
  end
end

dir = File.expand_path(File.join(File.dirname(__FILE__), 'web'))
