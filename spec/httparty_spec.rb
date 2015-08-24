require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

RSpec.describe HTTParty do
  before(:each) do
    @klass = Class.new
    @klass.instance_eval { include HTTParty }
  end

  describe "pem" do
    it 'should set the pem content' do
      @klass.pem 'PEM-CONTENT'
      expect(@klass.default_options[:pem]).to eq('PEM-CONTENT')
    end

    it "should set the password to nil if it's not provided" do
      @klass.pem 'PEM-CONTENT'
      expect(@klass.default_options[:pem_password]).to be_nil
    end

    it 'should set the password' do
      @klass.pem 'PEM-CONTENT', 'PASSWORD'
      expect(@klass.default_options[:pem_password]).to eq('PASSWORD')
    end
  end

  describe "pkcs12" do
    it 'should set the p12 content' do
      @klass.pkcs12 'P12-CONTENT', 'PASSWORD'
      expect(@klass.default_options[:p12]).to eq('P12-CONTENT')
    end

    it 'should set the password' do
      @klass.pkcs12 'P12-CONTENT', 'PASSWORD'
      expect(@klass.default_options[:p12_password]).to eq('PASSWORD')
    end
  end

  describe 'ssl_version' do
    it 'should set the ssl_version content' do
      @klass.ssl_version :SSLv3
      expect(@klass.default_options[:ssl_version]).to eq(:SSLv3)
    end
  end

  describe 'ciphers' do
    it 'should set the ciphers content' do
      expect(@klass.default_options[:ciphers]).to be_nil
      @klass.ciphers 'RC4-SHA'
      expect(@klass.default_options[:ciphers]).to eq('RC4-SHA')
    end
  end

  describe 'http_proxy' do
    it 'should set the address' do
      @klass.http_proxy 'proxy.foo.com', 80
      options = @klass.default_options
      expect(options[:http_proxyaddr]).to eq('proxy.foo.com')
      expect(options[:http_proxyport]).to eq(80)
    end

    it 'should set the proxy user and pass when they are provided' do
      @klass.http_proxy 'proxy.foo.com', 80, 'user', 'pass'
      options = @klass.default_options
      expect(options[:http_proxyuser]).to eq('user')
      expect(options[:http_proxypass]).to eq('pass')
    end
  end

  describe "base uri" do
    before(:each) do
      @klass.base_uri('api.foo.com/v1')
    end

    it "should have reader" do
      expect(@klass.base_uri).to eq('http://api.foo.com/v1')
    end

    it 'should have writer' do
      @klass.base_uri('http://api.foobar.com')
      expect(@klass.base_uri).to eq('http://api.foobar.com')
    end

    it 'should not modify the parameter during assignment' do
      uri = 'http://api.foobar.com'
      @klass.base_uri(uri)
      expect(uri).to eq('http://api.foobar.com')
    end
  end

  describe ".disable_rails_query_string_format" do
    it "sets the query string normalizer to HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER" do
      @klass.disable_rails_query_string_format
      expect(@klass.default_options[:query_string_normalizer]).to eq(HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER)
    end
  end

  describe ".normalize_base_uri" do
    it "should add http if not present for non ssl requests" do
      uri = HTTParty.normalize_base_uri('api.foobar.com')
      expect(uri).to eq('http://api.foobar.com')
    end

    it "should add https if not present for ssl requests" do
      uri = HTTParty.normalize_base_uri('api.foo.com/v1:443')
      expect(uri).to eq('https://api.foo.com/v1:443')
    end

    it "should not remove https for ssl requests" do
      uri = HTTParty.normalize_base_uri('https://api.foo.com/v1:443')
      expect(uri).to eq('https://api.foo.com/v1:443')
    end

    it 'should not modify the parameter' do
      uri = 'http://api.foobar.com'
      HTTParty.normalize_base_uri(uri)
      expect(uri).to eq('http://api.foobar.com')
    end

    it "should not treat uri's with a port of 4430 as ssl" do
      uri = HTTParty.normalize_base_uri('http://api.foo.com:4430/v1')
      expect(uri).to eq('http://api.foo.com:4430/v1')
    end
  end

  describe "headers" do
    def expect_headers(header = {})
      expect(HTTParty::Request).to receive(:new) \
        .with(anything, anything, hash_including({ headers: header })) \
        .and_return(double("mock response", perform: nil))
    end

    it "should default to empty hash" do
      expect(@klass.headers).to eq({})
    end

    it "should be able to be updated" do
      init_headers = {foo: 'bar', baz: 'spax'}
      @klass.headers init_headers
      expect(@klass.headers).to eq(init_headers)
    end

    it "uses the class headers when sending a request" do
      expect_headers(foo: 'bar')
      @klass.headers(foo: 'bar')
      @klass.get('')
    end

    it "merges class headers with request headers" do
      expect_headers(baz: 'spax', foo: 'bar')
      @klass.headers(foo: 'bar')
      @klass.get('', headers: {baz: 'spax'})
    end

    it 'overrides class headers with request headers' do
      expect_headers(baz: 'spax', foo: 'baz')
      @klass.headers(foo: 'bar')
      @klass.get('', headers: {baz: 'spax', foo: 'baz'})
    end

    context "with cookies" do
      it 'utilizes the class-level cookies' do
        expect_headers(foo: 'bar', 'cookie' => 'type=snickerdoodle')
        @klass.headers(foo: 'bar')
        @klass.cookies(type: 'snickerdoodle')
        @klass.get('')
      end

      it 'adds cookies to the headers' do
        expect_headers(foo: 'bar', 'cookie' => 'type=snickerdoodle')
        @klass.headers(foo: 'bar')
        @klass.get('', cookies: {type: 'snickerdoodle'})
      end

      it 'doesnt modify default_options' do
        expect(@klass.headers).to eq({})
        expect_headers('cookie' => 'type=snickerdoodle')
        @klass.get('', cookies: {type: 'snickerdoodle'})
        expect(@klass.default_options[:headers]).to eq({})
      end

      it 'adds optional cookies to the optional headers' do
        expect_headers(baz: 'spax', 'cookie' => 'type=snickerdoodle')
        @klass.get('', cookies: {type: 'snickerdoodle'}, headers: {baz: 'spax'})
      end
    end
  end

  describe "cookies" do
    def expect_cookie_header(s)
      expect(HTTParty::Request).to receive(:new) \
        .with(anything, anything, hash_including({ headers: { "cookie" => s } })) \
        .and_return(double("mock response", perform: nil))
    end

    it "should not be in the headers by default" do
      allow(HTTParty::Request).to receive(:new).and_return(double(nil, perform: nil))
      @klass.get("")
      expect(@klass.headers.keys).not_to include("cookie")
    end

    it "should raise an ArgumentError if passed a non-Hash" do
      expect do
        @klass.cookies("nonsense")
      end.to raise_error(ArgumentError)
    end

    it "should allow a cookie to be specified with a one-off request" do
      expect_cookie_header "type=snickerdoodle"
      @klass.get("", cookies: { type: "snickerdoodle" })
    end

    describe "when a cookie is set at the class level" do
      before(:each) do
        @klass.cookies({ type: "snickerdoodle" })
      end

      it "should include that cookie in the request" do
        expect_cookie_header "type=snickerdoodle"
        @klass.get("")
      end

      it "should pass the proper cookies when requested multiple times" do
        2.times do
          expect_cookie_header "type=snickerdoodle"
          @klass.get("")
        end
      end

      it "should allow the class defaults to be overridden" do
        expect_cookie_header "type=chocolate_chip"

        @klass.get("", cookies: { type: "chocolate_chip" })
      end
    end

    describe "in a class with multiple methods that use different cookies" do
      before(:each) do
        @klass.instance_eval do
          def first_method
            get("first_method", cookies: { first_method_cookie: "foo" })
          end

          def second_method
            get("second_method", cookies: { second_method_cookie: "foo" })
          end
        end
      end

      it "should not allow cookies used in one method to carry over into other methods" do
        expect_cookie_header "first_method_cookie=foo"
        @klass.first_method

        expect_cookie_header "second_method_cookie=foo"
        @klass.second_method
      end
    end
  end

  describe "default params" do
    it "should default to empty hash" do
      expect(@klass.default_params).to eq({})
    end

    it "should be able to be updated" do
      new_defaults = {foo: 'bar', baz: 'spax'}
      @klass.default_params new_defaults
      expect(@klass.default_params).to eq(new_defaults)
    end
  end

  describe "default timeout" do
    it "should default to nil" do
      expect(@klass.default_options[:timeout]).to eq(nil)
    end

    it "should support updating" do
      @klass.default_timeout 10
      expect(@klass.default_options[:timeout]).to eq(10)
    end

    it "should support floats" do
      @klass.default_timeout 0.5
      expect(@klass.default_options[:timeout]).to eq(0.5)
    end
  end

  describe "debug_output" do
    it "stores the given stream as a default_option" do
      @klass.debug_output $stdout
      expect(@klass.default_options[:debug_output]).to eq($stdout)
    end

    it "stores the $stderr stream by default" do
      @klass.debug_output
      expect(@klass.default_options[:debug_output]).to eq($stderr)
    end
  end

  describe "basic http authentication" do
    it "should work" do
      @klass.basic_auth 'foobar', 'secret'
      expect(@klass.default_options[:basic_auth]).to eq({username: 'foobar', password: 'secret'})
    end
  end

  describe "digest http authentication" do
    it "should work" do
      @klass.digest_auth 'foobar', 'secret'
      expect(@klass.default_options[:digest_auth]).to eq({username: 'foobar', password: 'secret'})
    end
  end

  describe "parser" do
    class CustomParser
      def self.parse(body)
        {sexy: true}
      end
    end

    let(:parser) do
      proc { |data, format| CustomParser.parse(data) }
    end

    it "should set parser options" do
      @klass.parser parser
      expect(@klass.default_options[:parser]).to eq(parser)
    end

    it "should be able parse response with custom parser" do
      @klass.parser parser
      FakeWeb.register_uri(:get, 'http://twitter.com/statuses/public_timeline.xml', body: 'tweets')
      custom_parsed_response = @klass.get('http://twitter.com/statuses/public_timeline.xml')
      expect(custom_parsed_response[:sexy]).to eq(true)
    end

    it "raises UnsupportedFormat when the parser cannot handle the format" do
      @klass.format :json
      class MyParser < HTTParty::Parser
        SupportedFormats = {}
      end unless defined?(MyParser)
      expect do
        @klass.parser MyParser
      end.to raise_error(HTTParty::UnsupportedFormat)
    end

    it 'does not validate format whe custom parser is a proc' do
      expect do
        @klass.format :json
        @klass.parser lambda {|body, format|}
      end.to_not raise_error
    end
  end

  describe "uri_adapter" do

    require 'forwardable'
    class CustomURIAdaptor
      extend Forwardable
      def_delegators :@uri, :userinfo, :relative?, :query, :query=, :scheme, :path, :host, :port

      def initialize uri
        @uri = uri
      end

      def self.parse uri
        new URI.parse uri
      end
    end

    let(:uri_adapter) { CustomURIAdaptor }

    it "should set the uri_adapter" do
      @klass.uri_adapter uri_adapter
      expect(@klass.default_options[:uri_adapter]).to be uri_adapter
    end

    it "should raise an ArgumentError if uri_adapter doesn't implement parse method" do
      expect do
        @klass.uri_adapter double()
      end.to raise_error(ArgumentError)
    end


    it "should process a request with a uri instance parsed from the uri_adapter" do
      uri = 'http://foo.com/bar'
      FakeWeb.register_uri(:get, uri, body: 'stuff')
      @klass.uri_adapter uri_adapter
      expect(@klass.get(uri).parsed_response).to eq('stuff')
    end

  end

  describe "connection_adapter" do
    let(:uri) { 'http://google.com/api.json' }
    let(:connection_adapter) { double('CustomConnectionAdapter') }

    it "should set the connection_adapter" do
      @klass.connection_adapter connection_adapter
      expect(@klass.default_options[:connection_adapter]).to be connection_adapter
    end

    it "should set the connection_adapter_options when provided" do
      options = {foo: :bar}
      @klass.connection_adapter connection_adapter, options
      expect(@klass.default_options[:connection_adapter_options]).to be options
    end

    it "should not set the connection_adapter_options when not provided" do
      @klass.connection_adapter connection_adapter
      expect(@klass.default_options[:connection_adapter_options]).to be_nil
    end

    it "should process a request with a connection from the adapter" do
      connection_adapter_options = {foo: :bar}
      expect(connection_adapter).to receive(:call) { |u, o|
        expect(o[:connection_adapter_options]).to eq(connection_adapter_options)
        HTTParty::ConnectionAdapter.call(u, o)
      }.with(URI.parse(uri), kind_of(Hash))
      FakeWeb.register_uri(:get, uri, body: 'stuff')
      @klass.connection_adapter connection_adapter, connection_adapter_options
      expect(@klass.get(uri).parsed_response).to eq('stuff')
    end
  end

  describe "format" do
    it "should allow xml" do
      @klass.format :xml
      expect(@klass.default_options[:format]).to eq(:xml)
    end

    it "should allow csv" do
      @klass.format :csv
      expect(@klass.default_options[:format]).to eq(:csv)
    end

    it "should allow json" do
      @klass.format :json
      expect(@klass.default_options[:format]).to eq(:json)
    end

    it "should allow plain" do
      @klass.format :plain
      expect(@klass.default_options[:format]).to eq(:plain)
    end

    it 'should not allow funky format' do
      expect do
        @klass.format :foobar
      end.to raise_error(HTTParty::UnsupportedFormat)
    end

    it 'should only print each format once with an exception' do
      expect do
        @klass.format :foobar
      end.to raise_error(HTTParty::UnsupportedFormat, "':foobar' Must be one of: csv, html, json, plain, xml")
    end

    it 'sets the default parser' do
      expect(@klass.default_options[:parser]).to be_nil
      @klass.format :json
      expect(@klass.default_options[:parser]).to eq(HTTParty::Parser)
    end

    it 'does not reset parser to the default parser' do
      my_parser = lambda {}
      @klass.parser my_parser
      @klass.format :json
      expect(@klass.parser).to eq(my_parser)
    end
  end

  describe "#no_follow" do
    it "sets no_follow to false by default" do
      @klass.no_follow
      expect(@klass.default_options[:no_follow]).to be_falsey
    end

    it "sets the no_follow option to true" do
      @klass.no_follow true
      expect(@klass.default_options[:no_follow]).to be_truthy
    end
  end

  describe "#maintain_method_across_redirects" do
    it "sets maintain_method_across_redirects to true by default" do
      @klass.maintain_method_across_redirects
      expect(@klass.default_options[:maintain_method_across_redirects]).to be_truthy
    end

    it "sets the maintain_method_across_redirects option to false" do
      @klass.maintain_method_across_redirects false
      expect(@klass.default_options[:maintain_method_across_redirects]).to be_falsey
    end
  end

  describe "#resend_on_redirect" do
    it "sets resend_on_redirect to true by default" do
      @klass.resend_on_redirect
      expect(@klass.default_options[:resend_on_redirect]).to be_truthy
    end

    it "sets resend_on_redirect option to false" do
      @klass.resend_on_redirect false
      expect(@klass.default_options[:resend_on_redirect]).to be_falsey
    end
  end

  describe ".follow_redirects" do
    it "sets follow redirects to true by default" do
      @klass.follow_redirects
      expect(@klass.default_options[:follow_redirects]).to be_truthy
    end

    it "sets the follow_redirects option to false" do
      @klass.follow_redirects false
      expect(@klass.default_options[:follow_redirects]).to be_falsey
    end
  end

  describe ".query_string_normalizer" do
    it "sets the query_string_normalizer option" do
      normalizer = proc {}
      @klass.query_string_normalizer normalizer
      expect(@klass.default_options[:query_string_normalizer]).to eq(normalizer)
    end
  end

  describe "with explicit override of automatic redirect handling" do
    before do
      @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', format: :xml, no_follow: true)
      @redirect = stub_response 'first redirect', 302
      @redirect['location'] = 'http://foo.com/bar'
      allow(HTTParty::Request).to receive_messages(new: @request)
    end

    it "should fail with redirected GET" do
      expect do
        @error = @klass.get('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected POST" do
      expect do
        @klass.post('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected PATCH" do
      expect do
        @klass.patch('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected DELETE" do
      expect do
        @klass.delete('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected MOVE" do
      expect do
        @klass.move('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected COPY" do
      expect do
        @klass.copy('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected PUT" do
      expect do
        @klass.put('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected HEAD" do
      expect do
        @klass.head('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end

    it "should fail with redirected OPTIONS" do
      expect do
        @klass.options('/foo', no_follow: true)
      end.to raise_error(HTTParty::RedirectionTooDeep) {|e| expect(e.response.body).to eq('first redirect')}
    end
  end

  describe "head requests should follow redirects requesting HEAD only" do
    before do
      allow(HTTParty::Request).to receive(:new).
        and_return(double("mock response", perform: nil))
    end

    it "should remain HEAD request across redirects, unless specified otherwise" do
      expect(@klass).to receive(:ensure_method_maintained_across_redirects).with({})
      @klass.head('/foo')
    end

  end

  describe "#ensure_method_maintained_across_redirects" do
    it "should set maintain_method_across_redirects option if unspecified" do
      options = {}
      @klass.send(:ensure_method_maintained_across_redirects, options)
      expect(options[:maintain_method_across_redirects]).to be_truthy
    end

    it "should not set maintain_method_across_redirects option if value is present" do
      options = { maintain_method_across_redirects: false }
      @klass.send(:ensure_method_maintained_across_redirects, options)
      expect(options[:maintain_method_across_redirects]).to be_falsey
    end
  end

  describe "with multiple class definitions" do
    before(:each) do
      @klass.instance_eval do
        base_uri "http://first.com"
        default_params one: 1
      end

      @additional_klass = Class.new
      @additional_klass.instance_eval do
        include HTTParty
        base_uri "http://second.com"
        default_params two: 2
      end
    end

    it "should not run over each others options" do
      expect(@klass.default_options).to eq({ base_uri: 'http://first.com', default_params: { one: 1 } })
      expect(@additional_klass.default_options).to eq({ base_uri: 'http://second.com', default_params: { two: 2 } })
    end
  end

  describe "two child classes inheriting from one parent" do
    before(:each) do
      @parent = Class.new do
        include HTTParty
        def self.name
          "Parent"
        end
      end

      @child1 = Class.new(@parent)
      @child2 = Class.new(@parent)
    end

    it "does not modify each others inherited attributes" do
      @child1.default_params joe: "alive"
      @child2.default_params joe: "dead"

      expect(@child1.default_options).to eq({ default_params: {joe: "alive"} })
      expect(@child2.default_options).to eq({ default_params: {joe: "dead"} })

      expect(@parent.default_options).to eq({ })
    end

    it "inherits default_options from the superclass" do
      @parent.basic_auth 'user', 'password'
      expect(@child1.default_options).to eq({basic_auth: {username: 'user', password: 'password'}})
      @child1.basic_auth 'u', 'p' # modifying child1 has no effect on child2
      expect(@child2.default_options).to eq({basic_auth: {username: 'user', password: 'password'}})
    end

    it "doesn't modify the parent's default options" do
      @parent.basic_auth 'user', 'password'

      @child1.basic_auth 'u', 'p'
      expect(@child1.default_options).to eq({basic_auth: {username: 'u', password: 'p'}})

      @child1.basic_auth 'email', 'token'
      expect(@child1.default_options).to eq({basic_auth: {username: 'email', password: 'token'}})

      expect(@parent.default_options).to eq({basic_auth: {username: 'user', password: 'password'}})
    end

    it "doesn't modify hashes in the parent's default options" do
      @parent.headers 'Accept' => 'application/json'
      @child1.headers 'Accept' => 'application/xml'

      expect(@parent.default_options[:headers]).to eq({'Accept' => 'application/json'})
      expect(@child1.default_options[:headers]).to eq({'Accept' => 'application/xml'})
    end

    it "works with lambda values" do
      @child1.default_options[:imaginary_option] = lambda { "This is a new lambda "}
      expect(@child1.default_options[:imaginary_option]).to be_a Proc
    end

    it 'should dup the proc on the child class' do
      imaginary_option = lambda { 2 * 3.14 }
      @parent.default_options[:imaginary_option] = imaginary_option
      expect(@parent.default_options[:imaginary_option].call).to eq(imaginary_option.call)
      @child1.default_options[:imaginary_option]
      expect(@child1.default_options[:imaginary_option].call).to eq(imaginary_option.call)
      expect(@child1.default_options[:imaginary_option]).not_to be_equal imaginary_option
    end

    it "inherits default_cookies from the parent class" do
      @parent.cookies 'type' => 'chocolate_chip'
      expect(@child1.default_cookies).to eq({"type" => "chocolate_chip"})
      @child1.cookies 'type' => 'snickerdoodle'
      expect(@child1.default_cookies).to eq({"type" => "snickerdoodle"})
      expect(@child2.default_cookies).to eq({"type" => "chocolate_chip"})
    end

    it "doesn't modify the parent's default cookies" do
      @parent.cookies 'type' => 'chocolate_chip'

      @child1.cookies 'type' => 'snickerdoodle'
      expect(@child1.default_cookies).to eq({"type" => "snickerdoodle"})

      expect(@parent.default_cookies).to eq({"type" => "chocolate_chip"})
    end
  end

  describe "grand parent with inherited callback" do
    before do
      @grand_parent = Class.new do
        def self.inherited(subclass)
          subclass.instance_variable_set(:@grand_parent, true)
        end
      end
      @parent = Class.new(@grand_parent) do
        include HTTParty
      end
    end
    it "continues running the #inherited on the parent" do
      child = Class.new(@parent)
      expect(child.instance_variable_get(:@grand_parent)).to be_truthy
    end
  end

  describe "#get" do
    it "should be able to get html" do
      stub_http_response_with('google.html')
      expect(HTTParty.get('http://www.google.com').parsed_response).to eq(file_fixture('google.html'))
    end

    it "should be able to get chunked html" do
      chunks = %w(Chunk1 Chunk2 Chunk3 Chunk4)
      stub_chunked_http_response_with(chunks)

      expect(
        HTTParty.get('http://www.google.com') do |fragment|
          expect(chunks).to include(fragment)
        end.parsed_response
      ).to eq(chunks.join)
    end

    it "should return an empty body if stream_body option is turned on" do
      chunks = %w(Chunk1 Chunk2 Chunk3 Chunk4)
      options = {stream_body: true, format: 'html'}
      stub_chunked_http_response_with(chunks, options)

      expect(
        HTTParty.get('http://www.google.com', options) do |fragment|
          expect(chunks).to include(fragment)
        end.parsed_response
      ).to eq(nil)
    end

    it "should be able parse response type json automatically" do
      stub_http_response_with('twitter.json')
      tweets = HTTParty.get('http://twitter.com/statuses/public_timeline.json')
      expect(tweets.size).to eq(20)
      expect(tweets.first['user']).to eq({
        "name"              => "Pyk",
        "url"               => nil,
        "id"                => "7694602",
        "description"       => nil,
        "protected"         => false,
        "screen_name"       => "Pyk",
        "followers_count"   => 1,
        "location"          => "Opera Plaza, California",
        "profile_image_url" => "http://static.twitter.com/images/default_profile_normal.png"
      })
    end

    it "should be able parse response type xml automatically" do
      stub_http_response_with('twitter.xml')
      tweets = HTTParty.get('http://twitter.com/statuses/public_timeline.xml')
      expect(tweets['statuses'].size).to eq(20)
      expect(tweets['statuses'].first['user']).to eq({
        "name"              => "Magic 8 Bot",
        "url"               => nil,
        "id"                => "17656026",
        "description"       => "ask me a question",
        "protected"         => "false",
        "screen_name"       => "magic8bot",
        "followers_count"   => "90",
        "profile_image_url" => "http://s3.amazonaws.com/twitter_production/profile_images/65565851/8ball_large_normal.jpg",
        "location"          => nil
      })
    end

    it "should be able parse response type csv automatically" do
      stub_http_response_with('twitter.csv')
      profile = HTTParty.get('http://twitter.com/statuses/profile.csv')
      expect(profile.size).to eq(2)
      expect(profile[0]).to eq(%w(name url id description protected screen_name followers_count profile_image_url location))
      expect(profile[1]).to eq(["Magic 8 Bot", nil, "17656026", "ask me a question", "false", "magic8bot", "90", "http://s3.amazonaws.com/twitter_production/profile_images/65565851/8ball_large_normal.jpg", nil])
    end

    it "should not get undefined method add_node for nil class for the following xml" do
      stub_http_response_with('undefined_method_add_node_for_nil.xml')
      result = HTTParty.get('http://foobar.com')
      expect(result.parsed_response).to eq({"Entities" => {"href" => "https://s3-sandbox.parature.com/api/v1/5578/5633/Account", "results" => "0", "total" => "0", "page_size" => "25", "page" => "1"}})
    end

    it "should parse empty response fine" do
      stub_http_response_with('empty.xml')
      result = HTTParty.get('http://foobar.com')
      expect(result).to be_nil
    end

    it "should accept http URIs" do
      stub_http_response_with('google.html')
      expect do
        HTTParty.get('http://google.com')
      end.not_to raise_error
    end

    it "should accept https URIs" do
      stub_http_response_with('google.html')
      expect do
        HTTParty.get('https://google.com')
      end.not_to raise_error
    end

    it "should accept webcal URIs" do
      uri = 'http://google.com/'
      FakeWeb.register_uri(:get, uri, body: 'stuff')
      uri = 'webcal://google.com/'
      expect do
        HTTParty.get(uri)
      end.not_to raise_error
    end

    it "should raise an InvalidURIError on URIs that can't be parsed at all" do
      expect do
        HTTParty.get("It's the one that says 'Bad URI'")
      end.to raise_error(URI::InvalidURIError)
    end
  end
end
