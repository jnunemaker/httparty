dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'oauth'
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.twitter_oauth')))

class Twitter
  include HTTParty
  base_uri 'twitter.com'
  
  def initialize(ck, cs, tk, ts)
    consumer = OAuth::Consumer.new(ck, cs, :site => 'http://twitter.com')
    @access_token = OAuth::AccessToken.new(consumer, tk, ts)
  end
  
  # which can be :friends, :user or :public
  # options[:query] can be things like since, since_id, count, etc.
  def timeline(which=:friends, options={})
    options.merge!({:oauth_auth => @access_token})
    self.class.get("/statuses/#{which}_timeline.json", options)
  end
end

# Get client key/secret from your app's page on dev.twitter.com
# To get access token/secret either do the normal access token request flow
# or generate one on your app page

twitter = Twitter.new(config['client_key'], config['client_secret'],
                      config['token_key'], config['token_secret'])

pp twitter.timeline
