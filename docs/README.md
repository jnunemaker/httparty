# httparty

Makes http fun again!

## Table of contents
- [Parsing JSON](#parsing-json)
- [File Uploads (Multipart)](#file-uploads-multipart)
- [Transports](#transports)
- [Persistent Connections](#persistent-connections)
- [Working with SSL](#working-with-ssl)

## Parsing JSON
If the response Content Type is `application/json`, HTTParty will parse the response and return Ruby objects such as a hash or array. The default behavior for parsing JSON will return keys as strings. This can be supressed with the `format` option. To get hash keys as symbols:

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

## Transports

HTTParty uses `HTTParty::Transport::NetHttp` by default. A client can select a
registered transport by name or provide a transport class directly:

```ruby
class Client
  include HTTParty

  transport :net_http
end

class ClientWithCustomTransport
  include HTTParty

  transport MyTransport, pool_size: 4
end
```

An adapter gem can register a short name before clients select it:

```ruby
HTTParty::Transport.register(:my_transport, MyTransport)

class Client
  include HTTParty
  transport :my_transport
end
```

Transport options are passed to the transport's constructor. A transport
instance is owned and reused by the HTTParty class, so it must be safe for
concurrent requests. Call `Client.close` when that client will no longer make
requests. Request-level overrides are also supported and are closed after the
request:

```ruby
Client.get('/resource', transport: MyTransport, transport_options: { pool_size: 1 })
```

### Curl

The curl transport is optional. Add `curb` to your application's bundle, then
select it on the client:

```ruby
# Gemfile
gem 'curb'

class Client
  include HTTParty

  transport :curl
end
```

The curl transport supports HTTParty headers, bodies, streaming responses,
timeouts, HTTP proxies, certificate verification, CA files, ciphers,
debug output, and local address/port binding. Redirects, cookies, authentication,
parsing, and decompression continue to be handled by HTTParty.

`open_timeout` maps to libcurl's connection timeout. `read_timeout`,
`write_timeout`, and the general `timeout` map to libcurl's total transfer
timeout, so their timing semantics are not identical to Net::HTTP. Request body
streams are currently buffered before the libcurl transfer; response streaming
remains incremental.

Options specific to `curb` can be namespaced under `curb_options`:

```ruby
transport :curl, curb_options: { dns_cache_timeout: 60 }
```

The curl transport rejects conflicting options it owns and Net::HTTP-specific
features it cannot faithfully provide, including `persistent_connections`,
`max_retries`, in-memory PEM/PKCS12 client certificates, OpenSSL certificate
stores and CA directories, and Ruby OpenSSL version selectors.

A transport implements this contract:

- `new(options = {})` creates the transport.
- `perform(request)` returns an `HTTParty::Transport::Response`.
- `perform(request) { |chunk| ... }` yields ordered
  `HTTParty::Transport::Chunk` objects and returns the response.
- `close` releases resources and can safely be called more than once.

The request exposes the HTTP method, URI, headers, body, body stream, and
HTTParty request options. Its `native` value is an optional compatibility escape
hatch and should not be required by portable transports. Responses expose an
integer status code, case-insensitive headers, body, HTTP version, reason phrase,
and an optional native response.

## Persistent Connections

Persistent connections are opt-in. Enable them on an HTTParty class to reuse
HTTP connections across requests:

```ruby
class Client
  include HTTParty

  base_uri 'https://example.com'
  persistent_connections(
    pool_size: 4,
    idle_timeout: 10,
    max_requests: 100
  )
end
```

The normalized options are `pool_size`, `idle_timeout`, and `max_requests`.
`pool_size` defaults to 4 concurrent HTTP transactions.
Existing HTTParty options such as timeouts, proxies, and SSL configuration
continue to work and remain request-overridable:

```ruby
Client.get(
  '/slow-resource',
  read_timeout: 30,
  persistent_connections: { idle_timeout: 20 }
)
```

Request-level persistent options merge with the class defaults. Pass
`persistent_connections: false` to disable connection reuse for one request.

Less common `net-http-persistent` settings can be passed through the namespaced
escape hatch:

```ruby
persistent_connections(
  net_http_persistent_options: {
    reuse_ssl_sessions: false,
    ignore_eof: true
  }
)
```

These advanced options follow `net-http-persistent` and are less stable than
HTTParty's normalized options. Unknown settings and settings already owned by
HTTParty raise `ArgumentError`.

When a client will no longer make requests, its connections can be closed:

```ruby
Client.shutdown_persistent_connections
```

Only shut down a client after its concurrent requests have finished.

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
# Use this example if you are using a pkcs12 file

class Client
  include HTTParty

  base_uri "https://example.com"
  ssl_ca_file "#{File.expand_path('.')}/path/to/certs/cert.pem"
end
```

#### Using `ssl_ca_path` option

```ruby
# Use this example if you are using a pkcs12 file

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
set the `Accept-Encoding` header on HTTParty requests. In this case, `Net::HTTP`
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
