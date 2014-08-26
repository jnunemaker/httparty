require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe HTTParty do
  before(:each) do
    @klass = Class.new
    @klass.instance_eval { include HTTParty }
  end

  describe "AllowedFormats deprecated" do
    before do
      Kernel.stub(:warn)
    end

    it "warns with a deprecation message" do
      Kernel.should_receive(:warn).with("Deprecated: Use HTTParty::Parser::SupportedFormats")
      HTTParty::AllowedFormats
    end

    it "returns HTTPart::Parser::SupportedFormats" do
      HTTParty::AllowedFormats.should == HTTParty::Parser::SupportedFormats
    end
  end

  describe "pem" do
    it 'should set the pem content' do
      @klass.pem 'PEM-CONTENT'
      @klass.default_options[:pem].should == 'PEM-CONTENT'
    end

    it "should set the password to nil if it's not provided" do
      @klass.pem 'PEM-CONTENT'
      @klass.default_options[:pem_password].should be_nil
    end

    it 'should set the password' do
      @klass.pem 'PEM-CONTENT', 'PASSWORD'
      @klass.default_options[:pem_password].should == 'PASSWORD'
    end
  end

  describe "pkcs12" do
    it 'should set the p12 content' do
      @klass.pkcs12 'P12-CONTENT', 'PASSWORD'
      @klass.default_options[:p12].should == 'P12-CONTENT'
    end

    it 'should set the password' do
      @klass.pkcs12 'P12-CONTENT', 'PASSWORD'
      @klass.default_options[:p12_password].should == 'PASSWORD'
    end
  end

  describe 'ssl_version' do
    it 'should set the ssl_version content' do
      @klass.ssl_version :SSLv3
      @klass.default_options[:ssl_version].should == :SSLv3
    end
  end

  describe 'ciphers' do
    it 'should set the ciphers content' do
      @klass.default_options[:ciphers].should be_nil
      @klass.ciphers 'RC4-SHA'
      @klass.default_options[:ciphers].should == 'RC4-SHA'
    end
  end

  describe 'http_proxy' do
    it 'should set the address' do
      @klass.http_proxy 'proxy.foo.com', 80
      options = @klass.default_options
      options[:http_proxyaddr].should == 'proxy.foo.com'
      options[:http_proxyport].should == 80
    end

    it 'should set the proxy user and pass when they are provided' do
      @klass.http_proxy 'proxy.foo.com', 80, 'user', 'pass'
      options = @klass.default_options
      options[:http_proxyuser].should == 'user'
      options[:http_proxypass].should == 'pass'
    end
  end

  describe "base uri" do
    before(:each) do
      @klass.base_uri('api.foo.com/v1')
    end

    it "should have reader" do
      @klass.base_uri.should == 'http://api.foo.com/v1'
    end

    it 'should have writer' do
      @klass.base_uri('http://api.foobar.com')
      @klass.base_uri.should == 'http://api.foobar.com'
    end

    it 'should not modify the parameter during assignment' do
      uri = 'http://api.foobar.com'
      @klass.base_uri(uri)
      uri.should == 'http://api.foobar.com'
    end
  end

  describe ".disable_rails_query_string_format" do
    it "sets the query string normalizer to HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER" do
      @klass.disable_rails_query_string_format
      @klass.default_options[:query_string_normalizer].should == HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER
    end
  end

  describe ".normalize_base_uri" do
    it "should add http if not present for non ssl requests" do
      uri = HTTParty.normalize_base_uri('api.foobar.com')
      uri.should == 'http://api.foobar.com'
    end

    it "should add https if not present for ssl requests" do
      uri = HTTParty.normalize_base_uri('api.foo.com/v1:443')
      uri.should == 'https://api.foo.com/v1:443'
    end

    it "should not remove https for ssl requests" do
      uri = HTTParty.normalize_base_uri('https://api.foo.com/v1:443')
      uri.should == 'https://api.foo.com/v1:443'
    end

    it 'should not modify the parameter' do
      uri = 'http://api.foobar.com'
      HTTParty.normalize_base_uri(uri)
      uri.should == 'http://api.foobar.com'
    end

    it "should not treat uri's with a port of 4430 as ssl" do
      uri = HTTParty.normalize_base_uri('http://api.foo.com:4430/v1')
      uri.should == 'http://api.foo.com:4430/v1'
    end
  end

  describe "headers" do
    def expect_headers(header={})
      HTTParty::Request.should_receive(:new) \
        .with(anything, anything, hash_including({ headers: header })) \
        .and_return(mock("mock response", perform: nil))
    end

    it "should default to empty hash" do
      @klass.headers.should == {}
    end

    it "should be able to be updated" do
      init_headers = {foo: 'bar', baz: 'spax'}
      @klass.headers init_headers
      @klass.headers.should == init_headers
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
        @klass.headers.should == {}
        expect_headers('cookie' => 'type=snickerdoodle')
        @klass.get('', cookies: {type: 'snickerdoodle'})
        @klass.default_options[:headers].should == {}
      end

      it 'adds optional cookies to the optional headers' do
        expect_headers(baz: 'spax', 'cookie' => 'type=snickerdoodle')
        @klass.get('', cookies: {type: 'snickerdoodle'}, headers: {baz: 'spax'})
      end
    end
  end

  describe "cookies" do
    def expect_cookie_header(s)
      HTTParty::Request.should_receive(:new) \
        .with(anything, anything, hash_including({ headers: { "cookie" => s } })) \
        .and_return(mock("mock response", perform: nil))
    end

    it "should not be in the headers by default" do
      HTTParty::Request.stub!(:new).and_return(stub(nil, perform: nil))
      @klass.get("")
      @klass.headers.keys.should_not include("cookie")
    end

    it "should raise an ArgumentError if passed a non-Hash" do
      lambda do
        @klass.cookies("nonsense")
      end.should raise_error(ArgumentError)
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
      @klass.default_params.should == {}
    end

    it "should be able to be updated" do
      new_defaults = {foo: 'bar', baz: 'spax'}
      @klass.default_params new_defaults
      @klass.default_params.should == new_defaults
    end
  end

  describe "default timeout" do
    it "should default to nil" do
      @klass.default_options[:timeout].should == nil
    end

    it "should support updating" do
      @klass.default_timeout 10
      @klass.default_options[:timeout].should == 10
    end

    it "should support floats" do
      @klass.default_timeout 0.5
      @klass.default_options[:timeout].should == 0.5
    end
  end

  describe "debug_output" do
    it "stores the given stream as a default_option" do
      @klass.debug_output $stdout
      @klass.default_options[:debug_output].should == $stdout
    end

    it "stores the $stderr stream by default" do
      @klass.debug_output
      @klass.default_options[:debug_output].should == $stderr
    end
  end

  describe "basic http authentication" do
    it "should work" do
      @klass.basic_auth 'foobar', 'secret'
      @klass.default_options[:basic_auth].should == {username: 'foobar', password: 'secret'}
    end
  end

  describe "digest http authentication" do
    it "should work" do
      @klass.digest_auth 'foobar', 'secret'
      @klass.default_options[:digest_auth].should == {username: 'foobar', password: 'secret'}
    end
  end

  describe "parser" do
    class CustomParser
      def self.parse(body)
        return {sexy: true}
      end
    end

    let(:parser) do
      Proc.new{ |data, format| CustomParser.parse(data) }
    end

    it "should set parser options" do
      @klass.parser parser
      @klass.default_options[:parser].should == parser
    end

    it "should be able parse response with custom parser" do
      @klass.parser parser
      FakeWeb.register_uri(:get, 'http://twitter.com/statuses/public_timeline.xml', body: 'tweets')
      custom_parsed_response = @klass.get('http://twitter.com/statuses/public_timeline.xml')
      custom_parsed_response[:sexy].should == true
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
      end.to_not raise_error(HTTParty::UnsupportedFormat)
    end
  end

  describe "connection_adapter" do
    let(:uri) { 'http://google.com/api.json' }
    let(:connection_adapter) { mock('CustomConnectionAdapter') }

    it "should set the connection_adapter" do
      @klass.connection_adapter connection_adapter
      @klass.default_options[:connection_adapter].should be connection_adapter
    end

    it "should set the connection_adapter_options when provided" do
      options = {foo: :bar}
      @klass.connection_adapter connection_adapter, options
      @klass.default_options[:connection_adapter_options].should be options
    end

    it "should not set the connection_adapter_options when not provided" do
      @klass.connection_adapter connection_adapter
      @klass.default_options[:connection_adapter_options].should be_nil
    end

    it "should process a request with a connection from the adapter" do
      connection_adapter_options = {foo: :bar}
      connection_adapter.should_receive(:call) do |u,o|
        o[:connection_adapter_options].should == connection_adapter_options
        HTTParty::ConnectionAdapter.call(u,o)
      end.with(URI.parse(uri), kind_of(Hash))
      FakeWeb.register_uri(:get, uri, body: 'stuff')
      @klass.connection_adapter connection_adapter, connection_adapter_options
      @klass.get(uri).should == 'stuff'
    end
  end

  describe "format" do
    it "should allow xml" do
      @klass.format :xml
      @klass.default_options[:format].should == :xml
    end

    it "should allow csv" do
      @klass.format :csv
      @klass.default_options[:format].should == :csv
    end

    it "should allow json" do
      @klass.format :json
      @klass.default_options[:format].should == :json
    end

    it "should allow plain" do
      @klass.format :plain
      @klass.default_options[:format].should == :plain
    end

    it 'should not allow funky format' do
      lambda do
        @klass.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat)
    end

    it 'should only print each format once with an exception' do
      lambda do
        @klass.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat, "':foobar' Must be one of: csv, html, json, plain, xml")
    end

    it 'sets the default parser' do
      @klass.default_options[:parser].should be_nil
      @klass.format :json
      @klass.default_options[:parser].should == HTTParty::Parser
    end

    it 'does not reset parser to the default parser' do
      my_parser = lambda {}
      @klass.parser my_parser
      @klass.format :json
      @klass.parser.should == my_parser
    end
  end

  describe "#no_follow" do
    it "sets no_follow to true by default" do
      @klass.no_follow
      @klass.default_options[:no_follow].should be_true
    end

    it "sets the no_follow option to false" do
      @klass.no_follow false
      @klass.default_options[:no_follow].should be_false
    end
  end

  describe "#maintain_method_across_redirects" do
    it "sets maintain_method_across_redirects to true by default" do
      @klass.maintain_method_across_redirects
      @klass.default_options[:maintain_method_across_redirects].should be_true
    end

    it "sets the maintain_method_across_redirects option to false" do
      @klass.maintain_method_across_redirects false
      @klass.default_options[:maintain_method_across_redirects].should be_false
    end
  end

  describe "#resend_on_redirect" do
    it "sets resend_on_redirect to true by default" do
      @klass.resend_on_redirect
      @klass.default_options[:resend_on_redirect].should be_true
    end

    it "sets resend_on_redirect option to false" do
      @klass.resend_on_redirect false
      @klass.default_options[:resend_on_redirect].should be_false
    end
  end

  describe ".follow_redirects" do
    it "sets follow redirects to true by default" do
      @klass.follow_redirects
      @klass.default_options[:follow_redirects].should be_true
    end

    it "sets the follow_redirects option to false" do
      @klass.follow_redirects false
      @klass.default_options[:follow_redirects].should be_false
    end
  end

  describe ".query_string_normalizer" do
    it "sets the query_string_normalizer option" do
      normalizer = proc {}
      @klass.query_string_normalizer normalizer
      @klass.default_options[:query_string_normalizer].should == normalizer
    end
  end

  describe "with explicit override of automatic redirect handling" do
    before do
      @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', format: :xml)
      @redirect = stub_response 'first redirect', 302
      @redirect['location'] = 'http://foo.com/bar'
      HTTParty::Request.stub(new: @request)
    end

    it "should fail with redirected GET" do
      lambda do
        @error = @klass.get('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected POST" do
      lambda do
        @klass.post('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected PATCH" do
      lambda do
        @klass.patch('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected DELETE" do
      lambda do
        @klass.delete('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected MOVE" do
      lambda do
        @klass.move('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected COPY" do
      lambda do
        @klass.copy('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected PUT" do
      lambda do
        @klass.put('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected HEAD" do
      lambda do
        @klass.head('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
    end

    it "should fail with redirected OPTIONS" do
      lambda do
        @klass.options('/foo')
      end.should raise_error(HTTParty::RedirectionTooDeep) {|e| e.response.body.should == 'first redirect'}
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
      @klass.default_options.should == { base_uri: 'http://first.com', default_params: { one: 1 } }
      @additional_klass.default_options.should == { base_uri: 'http://second.com', default_params: { two: 2 } }
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

      @child1.default_options.should == { default_params: {joe: "alive"} }
      @child2.default_options.should == { default_params: {joe: "dead"} }

      @parent.default_options.should == { }
    end

    it "inherits default_options from the superclass" do
      @parent.basic_auth 'user', 'password'
      @child1.default_options.should == {basic_auth: {username: 'user', password: 'password'}}
      @child1.basic_auth 'u', 'p' # modifying child1 has no effect on child2
      @child2.default_options.should == {basic_auth: {username: 'user', password: 'password'}}
    end

    it "doesn't modify the parent's default options" do
      @parent.basic_auth 'user', 'password'

      @child1.basic_auth 'u', 'p'
      @child1.default_options.should == {basic_auth: {username: 'u', password: 'p'}}

      @child1.basic_auth 'email', 'token'
      @child1.default_options.should == {basic_auth: {username: 'email', password: 'token'}}

      @parent.default_options.should == {basic_auth: {username: 'user', password: 'password'}}
    end

    it "doesn't modify hashes in the parent's default options" do
      @parent.headers 'Accept' => 'application/json'
      @child1.headers 'Accept' => 'application/xml'

      @parent.default_options[:headers].should == {'Accept' => 'application/json'}
      @child1.default_options[:headers].should == {'Accept' => 'application/xml'}
    end

    it "works with lambda values" do
      @child1.default_options[:imaginary_option] = lambda { "This is a new lambda "}
      @child1.default_options[:imaginary_option].should be_a Proc
    end

    it 'should dup the proc on the child class' do
      imaginary_option = lambda { 2 * 3.14 }
      @parent.default_options[:imaginary_option] = imaginary_option
      @parent.default_options[:imaginary_option].call.should == imaginary_option.call
      @child1.default_options[:imaginary_option]
      @child1.default_options[:imaginary_option].call.should == imaginary_option.call
      @child1.default_options[:imaginary_option].should_not be_equal imaginary_option
    end

    it "inherits default_cookies from the parent class" do
      @parent.cookies 'type' => 'chocolate_chip'
      @child1.default_cookies.should == {"type" => "chocolate_chip"}
      @child1.cookies 'type' => 'snickerdoodle'
      @child1.default_cookies.should == {"type" => "snickerdoodle"}
      @child2.default_cookies.should == {"type" => "chocolate_chip"}
    end

    it "doesn't modify the parent's default cookies" do
      @parent.cookies 'type' => 'chocolate_chip'

      @child1.cookies 'type' => 'snickerdoodle'
      @child1.default_cookies.should == {"type" => "snickerdoodle"}

      @parent.default_cookies.should == {"type" => "chocolate_chip"}
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
      child.instance_variable_get(:@grand_parent).should be_true
    end
  end

  describe "#get" do
    it "should be able to get html" do
      stub_http_response_with('google.html')
      HTTParty.get('http://www.google.com').should == file_fixture('google.html')
    end

    it "should be able to get chunked html" do
      chunks = ["Chunk1", "Chunk2", "Chunk3", "Chunk4"]
      stub_chunked_http_response_with(chunks)

      HTTParty.get('http://www.google.com') do |fragment|
        chunks.should include(fragment)
      end.should == chunks.join
    end

    it "should be able parse response type json automatically" do
      stub_http_response_with('twitter.json')
      tweets = HTTParty.get('http://twitter.com/statuses/public_timeline.json')
      tweets.size.should == 20
      tweets.first['user'].should == {
        "name"              => "Pyk",
        "url"               => nil,
        "id"                => "7694602",
        "description"       => nil,
        "protected"         => false,
        "screen_name"       => "Pyk",
        "followers_count"   => 1,
        "location"          => "Opera Plaza, California",
        "profile_image_url" => "http://static.twitter.com/images/default_profile_normal.png"
      }
    end

    it "should be able parse response type xml automatically" do
      stub_http_response_with('twitter.xml')
      tweets = HTTParty.get('http://twitter.com/statuses/public_timeline.xml')
      tweets['statuses'].size.should == 20
      tweets['statuses'].first['user'].should == {
        "name"              => "Magic 8 Bot",
        "url"               => nil,
        "id"                => "17656026",
        "description"       => "ask me a question",
        "protected"         => "false",
        "screen_name"       => "magic8bot",
        "followers_count"   => "90",
        "profile_image_url" => "http://s3.amazonaws.com/twitter_production/profile_images/65565851/8ball_large_normal.jpg",
        "location"          => nil
      }
    end

    it "should be able parse response type csv automatically" do
      stub_http_response_with('twitter.csv')
      profile = HTTParty.get('http://twitter.com/statuses/profile.csv')
      profile.size.should == 2
      profile[0].should == ["name","url","id","description","protected","screen_name","followers_count","profile_image_url","location"]
      profile[1].should == ["Magic 8 Bot",nil,"17656026","ask me a question","false","magic8bot","90","http://s3.amazonaws.com/twitter_production/profile_images/65565851/8ball_large_normal.jpg",nil]
    end

    it "should not get undefined method add_node for nil class for the following xml" do
      stub_http_response_with('undefined_method_add_node_for_nil.xml')
      result = HTTParty.get('http://foobar.com')
      result.should == {"Entities"=>{"href"=>"https://s3-sandbox.parature.com/api/v1/5578/5633/Account", "results"=>"0", "total"=>"0", "page_size"=>"25", "page"=>"1"}}
    end

    it "should parse empty response fine" do
      stub_http_response_with('empty.xml')
      result = HTTParty.get('http://foobar.com')
      result.should be_nil
    end

    it "should accept http URIs" do
      stub_http_response_with('google.html')
      lambda do
        HTTParty.get('http://google.com')
      end.should_not raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should accept https URIs" do
      stub_http_response_with('google.html')
      lambda do
        HTTParty.get('https://google.com')
      end.should_not raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should accept webcal URIs" do
      stub_http_response_with('google.html')
      lambda do
        HTTParty.get('webcal://google.com')
      end.should_not raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should raise an InvalidURIError on URIs that can't be parsed at all" do
      lambda do
        HTTParty.get("It's the one that says 'Bad URI'")
      end.should raise_error(URI::InvalidURIError)
    end
  end
end
