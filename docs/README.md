# httparty

Makes http fun again!

## Table of contents
- [Working with SSL](#working-with-ssl)

## Working with SSL

You can use this guide to work with SSL certificates.

#### Using `pem` option

```ruby
# Use this example if you are using a pem file

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

You can also include this options with the call:

```ruby
class Client
	include HTTParty
	
	base_uri "https://example.com"
	
	def	self.fetch
		get("/resources", pem: (File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456")
	end
end
```

### Avoid SSL verification

In some cases you may want to skip SSL verification, because the entity that issue the certificate is not a valid one, but you still want to work with it. You can achieve this through:

```ruby
#Skips SSL certificate verification

class Client
	include HTTParty

	base_uri "https://example.com"
	pem File.read("#{File.expand_path('.')}/path/to/certs/cert.pem"), "123456"
	
	def	self.fetch
		get("/resources", verify: false)
		# You can also use something like:
		# get("resources", verify_peer: false)
	end
end
```

### Using with `gitlab` gem

Add this to `~/.bashrc`, `_path` preffix avaiable for `p12` and `pem` only. If you need home path, use `ENV['HOME']` instead of `~`.

```

export GITLAB_API_HTTPARTY_OPTIONS="{verify: true, p12_path: '/path/to/key', p12_password_path: '/path/to/password' }"

```
