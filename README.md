# httparty

Makes http fun again!

## Install

```
gem install httparty
```

## Requirements

* multi_json and multi_xml
* You like to party!

## Examples

```ruby
# Use the class methods to get down to business quickly
response = HTTParty.get('http://twitter.com/statuses/public_timeline.json')
puts response.body, response.code, response.message, response.headers.inspect

response.each do |item|
  puts item['user']['screen_name']
end

# Or wrap things up in your own class
class Twitter
  include HTTParty
  base_uri 'twitter.com'

  def initialize(u, p)
    @auth = {:username => u, :password => p}
  end

  # which can be :friends, :user or :public
  # options[:query] can be things like since, since_id, count, etc.
  def timeline(which=:friends, options={})
    options.merge!({:basic_auth => @auth})
    self.class.get("/statuses/#{which}_timeline.json", options)
  end

  def post(text)
    options = { :body => {:status => text}, :basic_auth => @auth }
    self.class.post('/statuses/update.json', options)
  end
end

twitter = Twitter.new(config['email'], config['password'])
pp twitter.timeline
```

See the [examples directory](http://github.com/jnunemaker/httparty/tree/master/examples) for even more goodies.

## Command Line Interface

httparty also includes the executable `httparty` which can be
used to query web services and examine the resulting output. By default
it will output the response as a pretty-printed Ruby object (useful for
grokking the structure of output). This can also be overridden to output
formatted XML or JSON. Execute `httparty --help` for all the
options. Below is an example of how easy it is.

```
httparty "http://twitter.com/statuses/public_timeline.json"
```

## Help and Docs

* https://groups.google.com/forum/#!forum/httparty-gem
* http://rdoc.info/projects/jnunemaker/httparty

## Contributing

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself in another branch so I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.
