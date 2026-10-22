$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

class Rubyurl
  include HTTParty
  base_uri 'rubyurl.com'

  def self.shorten(website_url)
    post('/api/links.json', query: { link: { website_url: website_url } })
  end
end

pp Rubyurl.shorten('http://istwitterdown.com/')
