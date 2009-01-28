dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'

# You can also use post, put, delete in the same fashion
response = HTTParty.get('http://twitter.com/statuses/public_timeline.json')
pp response

response.each do |item|
  puts item['user']['screen_name']
end