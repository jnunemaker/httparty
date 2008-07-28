dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.twitter')))

class Twitter
  include HTTParty
  
  # sets the base url for each request
  base_uri 'twitter.com'
  
  def initialize(user, pass)
    # set basic http authentication for all requests
    self.class.basic_auth user, pass
  end
  
  # which can be :friends, :user or :public
  # options[:query] can be things like since, since_id, count, etc.
  def timeline(which=:friends, options={})
    self.class.get("/statuses/#{which}_timeline.xml", options)['statuses'].map { |s| s.to_struct }
  end
  
  def post(text)
    self.class.post('/statuses/update.xml', :query => {:status => text})['status'].to_struct
  end
end


twitter = Twitter.new(config['email'], config['password'])

twitter.timeline.each do |s|
  puts s.user.name, s.text, "#{s.created_at} #{s.id}", ''
end

# twitter.timeline(:friends, :query => {:since_id => 868482746}).each do |s|
#   puts s.user.name, s.text, "#{s.created_at} #{s.id}", ''
# end
# 
# pp twitter.post('this is a test')