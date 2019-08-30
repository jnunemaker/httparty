# httparty

Makes http fun again!  Ain't no party like a httparty, because a httparty don't stop.

## Install

```
gem install httparty
```

## Requirements

* Ruby 2.0.0 or higher
* multi_xml
* You like to party!

## Examples

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

See the [examples directory](http://github.com/jnunemaker/httparty/tree/master/examples) for even more goodies.

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

* https://www.rubydoc.info/github/jnunemaker/httparty
* http://stackoverflow.com/questions/tagged/httparty


### Table of contents
- [Options](#options)
- [Parsing JSON](#parsing-json)
- [Working with SSL](#working-with-ssl)

### Options

HTTParty provides lot's of options for customization

##### Request Options

- :body - Body of the request. If passed an object that responds to #to_hash, will try to normalize it first, by default passing it to ActiveSupport::to_params. Any other kind of object will get used as-is.
- :http_proxyaddr - Address of proxy server to use.
- :http_proxyport -  Port of proxy server to use.
- :http_proxyuser - User for proxy server authentication.
- :http_proxypass - Password for proxy server authentication.
- :limit - Maximum number of redirects to follow. Takes precedences over :no_follow.
- :query - Query string, or an object that responds to #to_hash representing it. Normalized according to the same rules as :+body+. If you specify this on a POST, you must use an object which responds to #to_hash. See also HTTParty::ClassMethods.default_params.
- :default_timeout - Timeout for opening connection and reading data.
- :open_timeout - Timeout for opening connection.
- :read_timeout - Timeout for reading data.
- :write_timeout - Timeout for writtin data.
- :local_host - Local address to bind to before connecting.
- :local_port - Local port to bind to before connecting.
- :max_retries - Allows to specify number of retries on unsuccessful request.
- :body_stream - Allow streaming to a REST server to specify a body_stream.
- :stream_body - Allow for streaming large files without loading them into memory.
- :multipart - Force content-type to be multipart
- :raise_on - Raises HTTParty::ResponseError if response's code matches this statuses

#### Request and Class Options
There are also another set of options with names corresponding to various class methods. The methods in question are those that let you set a class-wide default, and the options override the defaults on a request-by-request basis. Those options are:

- :base_uri -- Allows setting a base uri to be used for each request. Will normalize uri to include http, etc.
- :basic_auth -- see HTTParty::ClassMethods.basic_auth. Only one of :+basic_auth+ and :+digest_auth+ can be used at a time; if you try using both, you'll get an ArgumentError.
- :digest_auth -- see HTTParty::ClassMethods.digest_auth. Only one of `:basic_auth` and `:digest_auth` can be used at a time; if you try using both, you'll get an ArgumentError.
- :debug_output -- see HTTParty::ClassMethods.debug_output.
- :format -- see HTTParty::ClassMethods.format.
- :headers -- see HTTParty::ClassMethods.headers. Must be a an object which responds to `#to_hash`.
- :maintain_method_across_redirects -- see HTTParty::ClassMethods.maintain_method_across_redirects.
- :no_follow -- see HTTParty::ClassMethods.no_follow.
- :parser -- see HTTParty::ClassMethods.parser.
- :uri_adapter -- see HTTParty::ClassMethods.uri_adapter
- :connection_adapter -- see HTTParty::ClassMethods.connection_adapter.
- :pem -- see HTTParty::ClassMethods.pem.
- :query_string_normalizer -- see HTTParty::ClassMethods.query_string_normalizer
- :ssl_ca_file -- see HTTParty::ClassMethods.ssl_ca_file.
- :ssl_ca_path -- see HTTParty::ClassMethods.ssl_ca_path.


### Parsing JSON
If the response Content Type is `application/json`, HTTParty will parse the response and return Ruby objects such as a hash or array. The default behavior for parsing JSON will return keys as strings. This can be supressed with the `format` option. To get hash keys as symbols:

```ruby
response = HTTParty.get('http://example.com', format: :plain)
JSON.parse response, symbolize_names: true
```

### Multipart

If you are uploading file in params, multipart will used as content-type automatically
```ruby
HTTParty.post(
  'http://localhost:3000/user',
  body: {
    name: 'Foo Bar',
    email: 'example@email.com',
    avatar: File.open('/full/path/to/avatar.jpg')
  }
)
```

However, you can force it yourself with `:multipart` option
```ruby
HTTParty.post(
  'http://localhost:3000/user',
  multipart: true,
  body: {
    name: 'Foo Bar',
    email: 'example@email.com'
  }
)
```


### Working with SSL

You can use this guide to work with SSL certificates.

##### Using `pem` option

```ruby
# Use this example if you are using a pem file

class Client
  include HTTParty

  base_uri "https://example.com"
  pem File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456"
end
```

##### Using `pkcs12` option

```ruby
# Use this example if you are using a pkcs12 file

class Client
  include HTTParty

  base_uri "https://example.com"
  pkcs12 File.read("#{File.expand_path('.')}/path/to/certs/cert.p12"), "123456"
end
```

##### Using `ssl_ca_file` option

```ruby
# Use this example if you are using a pkcs12 file

class Client
  include HTTParty

  base_uri "https://example.com"
  ssl_ca_file "#{File.expand_path('.')}/path/to/certs/cert.pem"
end
```

##### Using `ssl_ca_path` option

```ruby
# Use this example if you are using a pkcs12 file

class Client
  include HTTParty

  base_uri "https://example.com"
  ssl_ca_path '/path/to/certs'
end
```

You can also include this options with the call:

```ruby
class Client
  include HTTParty

  base_uri "https://example.com"

  def self.fetch
    get("/resources", pem: (File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456")
  end
end
```

#### Avoid SSL verification

In some cases you may want to skip SSL verification, because the entity that issue the certificate is not a valid one, but you still want to work with it. You can achieve this through:

```ruby
# Skips SSL certificate verification

class Client
  include HTTParty

  base_uri "https://example.com"
  pem File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456"

  def self.fetch
    get("/resources", verify: false)
    # You can also use something like:
    # get("resources", verify_peer: false)
  end
end
```

### Dynamic Headers

### Internation Domain Names (IDNs)


## Contributing

* Fork the project.
* Run `bundle`
* Run `bundle exec rake`
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Run `bundle exec rake` (No, REALLY :))
* Commit, do not mess with rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself in another branch so I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.
