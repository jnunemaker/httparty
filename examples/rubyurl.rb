dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')

class Rubyurl
  include HTTParty
  base_uri 'rubyurl.com'

  def self.shorten(website_url)
    xml = post('/api/links.json', :query => {'link[website_url]' => website_url})
    xml['link'] && xml['link']['permalink']
  end
end

puts Rubyurl.shorten( 'http://istwitterdown.com/' ).inspect
