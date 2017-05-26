[![Build Status](https://travis-ci.org/jnunemaker/httparty.svg?branch=master)](https://travis-ci.org/jnunemaker/httparty)
[![Code Climate](https://codeclimate.com/github/jnunemaker/httparty/badges/gpa.svg)](https://codeclimate.com/github/jnunemaker/httparty)
[![Test Coverage](https://codeclimate.com/github/jnunemaker/httparty/badges/coverage.svg)](https://codeclimate.com/github/jnunemaker/httparty)

# httparty

Makes http fun again!

## Install

```
gem install httparty
```

## Requirements

* Ruby 2.0.0 or higher
* multi_xml
* You like to party!

## Get request examples

```ruby
# Use the class methods to get down to business quickly
response = HTTParty.get('http://api.stackexchange.com/2.2/questions?site=stackoverflow')

puts response.body, response.code, response.message, response.headers.inspect

# Or wrap things up in your own class
class StackExchange
  include HTTParty
  base_uri 'api.stackexchange.com'

  def initialize(service, page)
    @options = { query: { site: service, page: page } }
  end

  def questions
    self.class.get("/2.2/questions", @options)
  end

  def users
    self.class.get("/2.2/users", @options)
  end
end

stack_exchange = StackExchange.new("stackoverflow", 1)
puts stack_exchange.questions
puts stack_exchange.users
```

## Post request examples

The following is a simple example of wrapping Twitter's API for posting updates. Note if you want to put data in HTTP body you should use :body root key instead :query.

```ruby
class Twitter
  include HTTParty
  base_uri 'twitter.com'
  basic_auth 'username', 'password'
end

Twitter.post('/statuses/update.json', body: {status: "It's an HTTParty and everyone is invited!"})
```

That is really it! The object returned is a ruby hash that is decoded from Twitter's json response. JSON parsing is used because of the .json extension in the path of the request. You can also explicitly set a format (see the examples).

That works and all but what if you don't want to embed your username and password in the class? Below is an example to fix that:

```ruby
class Twitter
  include HTTParty
  base_uri 'twitter.com'

  def initialize(u, p)
    @auth = {username: u, password: p}
  end

  def post(text)
    options = { body: {status: text}, basic_auth: @auth }
    self.class.post('/statuses/update.json', options)
  end
end

Twitter.new('username', 'password').post("It's an HTTParty and everyone is invited!")
```

###See the [examples directory](http://github.com/jnunemaker/httparty/tree/master/examples) for even more goodies.

## Command Line Interface

httparty also includes the executable `httparty` which can be
used to query web services and examine the resulting output. By default
it will output the response as a pretty-printed Ruby object (useful for
grokking the structure of output). This can also be overridden to output
formatted XML or JSON. Execute `httparty --help` for all the
options. Below is an example of how easy it is.

```
httparty "https://api.stackexchange.com/2.2/questions?site=stackoverflow"
```

## Help and Docs

* [Docs](https://github.com/jnunemaker/httparty/tree/master/docs)
* https://groups.google.com/forum/#!forum/httparty-gem
* http://rdoc.info/projects/jnunemaker/httparty
* http://stackoverflow.com/questions/tagged/httparty

## Contributing

* Fork the project.
* Run `bundle`
* Run `bundle exec rake`
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Run `bundle exec rake` (No, REALLY :))
* Commit, do not mess with rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself in another branch so I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.
