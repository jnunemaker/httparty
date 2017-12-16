require 'httparty'
require 'pp'

class RequestViaSocksProxy
  include HTTParty
  proxy_addr, proxy_port = ENV.fetch('SOCKS_PROXY').split(':')
  socks_proxy proxy_addr, proxy_port.to_i
  headers 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko'
end

# This request will happen by using the socks proxy.
pp RequestViaSocksProxy.get('https://whatismyipaddress.com')
