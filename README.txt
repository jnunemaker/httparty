= httparty

== DESCRIPTION:

Makes http fun again!

== FEATURES/PROBLEMS:

* Easy get, post, put, delete requests
* Basic http authentication
* Default request query string parameters (ie: for api keys that are needed on each request)
* Automatic parsing of JSON and XML into ruby hashes based on response content-type

== SYNOPSIS:

The following is a simple example of wrapping Twitter's API for posting updates.

	class Twitter
	  include HTTParty
	  base_uri 'twitter.com'
	  basic_auth 'username', 'password'
	end

	Twitter.post('/statuses/update.json', :query => {:status => "It's an HTTParty and everyone is invited!"})

That is really it! The object returned is a ruby hash that is decoded from Twitter's json response. JSON parsing is used because of the .json extension in the path of the request. You can also explicitly set a format (see the examples). 

That works and all but what if you don't want to embed your username and password in the class? Below is an example to fix that:

	class Twitter
	  include HTTParty
	  base_uri 'twitter.com'

	  def initialize(u, p)
	    @auth = {:username => u, :password => p}
	  end

	  def post(text)
	    options = { :query => {:status => text}, :basic_auth => @auth }
	    self.class.post('/statuses/update.json', options)
	  end
	end
	
	Twitter.new('username', 'password').post("It's an HTTParty and everyone is invited!")

=== REQUEST OPTIONS

Each of the HTTP method (get, post, put and delete) each take a hash of options.
The following keys can be specified in the options:

headers::       A <tt>Hash</tt> of header key/value pairs
query::         A <tt>Hash</tt> of query key/value pairs
body::          The body of the request. If it's a <tt>Hash</tt>, it is
                converted into query-string format, otherwise it is sent
                as-is.
basic_auth::    A <tt>Hash</tt> containing keys for <tt>:username</tt> and
                <tt>:password</tt>.
no_follow::     Turns off automatic redirect following

== REQUIREMENTS:

* Active Support >= 2.1

== INSTALL:

* sudo gem install httparty