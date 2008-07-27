dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'web')
config = YAML::load(File.read(File.join(ENV['HOME'], '.twitter')))

class Twitter
  include Web
  base_uri 'twitter.com'
end

Twitter.basic_auth config['email'], config['password']
puts Twitter.get('/statuses/user_timeline.json')

# puts Twitter.post('/direct_messages/new.xml', :query => {:user => 'jnunemaker', :text => 'Hello from Web'})
# puts Twitter.response.code