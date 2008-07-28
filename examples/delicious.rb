dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.delicious')))

class Delicious
  include HTTParty
  
  base_uri 'https://api.del.icio.us/v1'
  format :xml
  
  def initialize(user, pass)
    self.class.basic_auth(user, pass)
  end
  
  # query params that filter the posts are:
  #   tag (optional). Filter by this tag.
  #   dt (optional). Filter by this date (CCYY-MM-DDThh:mm:ssZ).
  #   url (optional). Filter by this url.
  #   ie: posts(:query => {:tag => 'ruby'})
  def posts(options={})
    self.class.get('/posts/get', options)['posts']['post'].map { |b| b.to_struct }
  end
  
  # query params that filter the posts are:
  #   tag (optional). Filter by this tag.
  #   count (optional). Number of items to retrieve (Default:15, Maximum:100).
  def recent(options={})
    self.class.get('/posts/recent', options)['posts']['post'].map { |b| b.to_struct }
  end
end

pp Delicious.new(config['username'], config['password']).posts

puts '', 'RECENT'
pp Delicious.new(config['username'], config['password']).recent

