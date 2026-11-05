# httparty

Makes http fun again!

## Table of contents
- [Parsing JSON](#parsing-json)
- [File Uploads (Multipart)](#file-uploads-multipart)
- [Working with SSL](#working-with-ssl)
- [Timeouts and Retries](#timeouts-and-retries)

## Parsing JSON
If the response Content Type is `application/json`, HTTParty will parse the response and return Ruby objects such as a hash or array. The default behavior for parsing JSON will return keys as strings. This can be suppressed with the `format` option. To get hash keys as symbols:

```ruby
response = HTTParty.get('http://example.com', format: :plain)
JSON.parse response, symbolize_names: true
```

## Posting JSON
When using Content Type `application/json` with `POST`, `PUT` or `PATCH` requests, the body should be a string of valid JSON:

```ruby
# With written JSON
HTTParty.post('http://example.com', body: "{\"foo\":\"bar\"}", headers: { 'Content-Type' => 'application/json' })

# Using JSON.generate
HTTParty.post('http://example.com', body: JSON.generate({ foo: 'bar' }), headers: { 'Content-Type' => 'application/json' })

# Using object.to_json
HTTParty.post('http://example.com', body: { foo: 'bar' }.to_json, headers: { 'Content-Type' => 'application/json' })
```

## File Uploads (Multipart)

When you include a `File` object in the body, HTTParty automatically uses `multipart/form-data` encoding:

```ruby
HTTParty.post('http://example.com/upload',
  body: {
    name: 'Foo Bar',
    avatar: File.open('/path/to/avatar.jpg')
  }
)
```

### Streaming Uploads for Large Files

For large file uploads, you can enable streaming mode to reduce memory usage. Instead of loading the entire file into memory, HTTParty will stream the file in chunks:

```ruby
HTTParty.post('http://example.com/upload',
  body: {
    name: 'Foo Bar',
    avatar: File.open('/path/to/large_file.zip')
  },
  stream_body: true
)
```

**Note:** Some servers may not handle streaming uploads correctly. If you encounter issues (e.g., 400 errors), try without the `stream_body` option.

## Working with SSL

You can use this guide to work with SSL certificates.

#### Using `pem` option

```ruby
# Use this example if you are using a pem file
# - cert.pem must contain the content of a PEM file having the private key appended (separated from the cert by a newline \n)
# - Use an empty string for the password if the cert is not password protected

class Client
  include HTTParty

  base_uri "https://example.com"
  pem File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456"
end
```

#### Using `pkcs12` option

```ruby
# Use this example if you are using a pkcs12 file

class Client
  include HTTParty

  base_uri "https://example.com"
  pkcs12 File.read("#{File.expand_path('.')}/path/to/certs/cert.p12"), "123456"
end
```

#### Using `ssl_ca_file` option

```ruby
# Use this example to verify the server against the CA certificates in a PEM file

class Client
  include HTTParty

  base_uri "https://example.com"
  ssl_ca_file "#{File.expand_path('.')}/path/to/certs/cert.pem"
end
```

#### Using `ssl_ca_path` option

```ruby
# Use this example to verify the server against a directory of CA certificates

class Client
  include HTTParty

  base_uri "https://example.com"
  ssl_ca_path '/path/to/certs'
end
```

You can also include all of these options with the call:

```ruby
class Client
  include HTTParty

  base_uri "https://example.com"

  def self.fetch
    get("/resources", pem: File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), pem_password: "123456")
  end
end
```

### Avoid SSL verification

In some cases you may want to skip SSL verification, because the entity that issued the certificate is not a valid one, but you still want to work with it. You can achieve this through:

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

### HTTP Compression

The `Accept-Encoding` request header and `Content-Encoding` response header
are used to control compression (gzip, etc.) over the wire. Refer to
[RFC-2616](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html) for details.
(For clarity: these headers are **not** used for character encoding i.e. `utf-8`
which is specified in the `Accept` and `Content-Type` headers.)

Unless you have specific requirements otherwise, we recommend to **not** set
the `Accept-Encoding` header on HTTParty requests. In this case, `Net::HTTP`
will set a sensible default compression scheme and automatically decompress the response.

If you explicitly set `Accept-Encoding`, there be dragons:

* If the HTTP response `Content-Encoding` received on the wire is `gzip` or `deflate`,
  `Net::HTTP` will automatically decompress it, and will omit `Content-Encoding`
  from your `HTTParty::Response` headers.

* For the following encodings, HTTParty will automatically decompress them if you include
  the required gem into your project. Similar to above, if decompression succeeds,
  `Content-Encoding` will be omitted from your `HTTParty::Response` headers.
  **Warning:** Support for these encodings is experimental and not fully battle-tested.

  | Content-Encoding | Required Gem |
  | --- | --- |
  | `br` (Brotli)      | [brotli](https://rubygems.org/gems/brotli) |
  | `compress` (LZW)   | [ruby-lzws](https://rubygems.org/gems/ruby-lzws) |
  | `zstd` (Zstandard) | [zstd-ruby](https://rubygems.org/gems/zstd-ruby) |

* For other encodings, `HTTParty::Response#body` will return the raw uncompressed byte string,
  and you'll need to inspect the `Content-Encoding` response header and decompress it yourself.
  In this case, `HTTParty::Response#parsed_response` will be `nil`.

* Lastly, you may use the `skip_decompression` option to disable all automatic decompression
  and always get `HTTParty::Response#body` in its raw form along with the `Content-Encoding` header.

```ruby
# Accept-Encoding=gzip,deflate can be safely assumed to be auto-decompressed

res = HTTParty.get('https://example.com/test.json', headers: { 'Accept-Encoding' => 'gzip,deflate,identity' })
JSON.parse(res.body) # safe


# Accept-Encoding=br,compress requires third-party gems

require 'brotli'
require 'lzws'
require 'zstd-ruby'
res = HTTParty.get('https://example.com/test.json', headers: { 'Accept-Encoding' => 'br,compress,zstd' })
JSON.parse(res.body)


# Accept-Encoding=* may return unhandled Content-Encoding

res = HTTParty.get('https://example.com/test.json', headers: { 'Accept-Encoding' => '*' })
encoding = res.headers['Content-Encoding']
if encoding
JSON.parse(your_decompression_handling(res.body, encoding))
else
# Content-Encoding not present implies decompressed
JSON.parse(res.body)
end


# Gimme the raw data!

res = HTTParty.get('https://example.com/test.json', skip_decompression: true)
encoding = res.headers['Content-Encoding']
JSON.parse(your_decompression_handling(res.body, encoding))
```

## Timeouts and Retries

HTTParty doesn't set timeouts of its own, so a request uses Net::HTTP's defaults: 60 seconds each to open the connection, read and write. Set shorter ones for anything a person is waiting on:

```ruby
# One request
HTTParty.get('https://example.com', timeout: 5) # open, read and write
HTTParty.get('https://example.com', open_timeout: 2, read_timeout: 10)

# Every request a class makes
class Client
  include HTTParty
  base_uri 'https://example.com'
  open_timeout 2
  read_timeout 10
end
```

`open_timeout`, `read_timeout` and `write_timeout` take precedence over `timeout`. Timeouts must be an Integer or a Float, and `max_retries` an Integer. The timeout class methods raise `ArgumentError` for anything else, but a request option of another type is silently ignored, so convert values read from `ENV` first (`Integer(ENV['API_TIMEOUT'])`).

A timeout raises `Net::OpenTimeout`, `Net::ReadTimeout` or `Net::WriteTimeout` (all `Timeout::Error`s), or `HTTParty::NetworkError` when `foul` is on.

Net::HTTP retries a request once, right away, if it times out or the connection fails after it opens, but only for idempotent methods (GET, HEAD, PUT, DELETE, OPTIONS and TRACE). A connection that fails to open isn't retried. So a GET with `read_timeout: 5` can take about 10 seconds before it raises. Use `max_retries` to change the number of retries:

```ruby
HTTParty.get('https://example.com', read_timeout: 5, max_retries: 0)

class Client
  include HTTParty
  default_options[:max_retries] = 0
end
```
