dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')
require 'pp'
config = YAML::load(File.read(File.join(ENV['HOME'], '.delicious')))

class Delicious
  include HTTParty
  
  # sets the base url for each request
  base_uri 'https://api.del.icio.us/v1'
  
  # parse xml automatically
  format :xml
  
  def initialize(user, pass)
    # set basic http authentication for all requests
    self.class.basic_auth(user, pass)
  end
  
  # query params that filter the posts are:
  #   tag (optional). Filter by this tag.
  #   dt (optional). Filter by this date (CCYY-MM-DDThh:mm:ssZ).
  #   url (optional). Filter by this url.
  #   ie: posts(:query => {:tag => 'ruby'})
  def posts(options={})
    # get posts and convert to structs so we can do .key instead of ['key'] with results
    self.class.get('/posts/get', options)['posts']['post'].map { |b| b.to_struct }
  end
  
  # query params that filter the posts are:
  #   tag (optional). Filter by this tag.
  #   count (optional). Number of items to retrieve (Default:15, Maximum:100).
  def recent(options={})
    self.class.get('/posts/recent', options)['posts']['post'].map { |b| b.to_struct }
  end
end

delicious = Delicious.new(config['username'], config['password'])

pp delicious.posts(:query => {:tag => 'ruby'})

puts '', '*' * 50, ''

pp delicious.recent

