dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'web')
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.twitter')))

class Twitter
  include Web
  base_uri 'twitter.com'
  format :xml
  
  def initialize(user, pass)
    self.class.basic_auth user, pass
  end
  
  def timeline
    self.class.get('/statuses/user_timeline.xml')['statuses'].map(&:to_struct)
  end
end

twitter = Twitter.new(config['email'], config['password'])
statuses = twitter.timeline
pp statuses

statuses.each do |s|
  puts s.user.name
  puts s.text
  puts s.created_at
  puts '', ''
end