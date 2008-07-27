dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'web')
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.twitter')))

class Twitter
  include Web
  
  base_uri 'twitter.com'
  format :xml
  
  entity :status
  entity :user
end

Twitter.basic_auth config['email'], config['password']
pp Twitter.get('/statuses/user_timeline.xml', :entity => :status)