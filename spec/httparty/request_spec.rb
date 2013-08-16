require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::Request do
  before do
    @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', :format => :xml)
  end

  describe "::NON_RAILS_QUERY_STRING_NORMALIZER" do
    let(:normalizer) { HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER }

    it "doesn't modify strings" do
      query_string = normalizer["foo=bar&foo=baz"]
      URI.unescape(query_string).should == "foo=bar&foo=baz"
    end

    context "when the query is an array" do

      it "doesn't include brackets" do
        query_string = normalizer[{:page => 1, :foo => %w(bar baz)}]
        URI.unescape(query_string).should == "foo=bar&foo=baz&page=1"
      end

      it "URI encodes array values" do
        query_string = normalizer[{:people => ["Bob Marley", "Tim & Jon"]}]
        query_string.should == "people=Bob%20Marley&people=Tim%20%26%20Jon"
      end
    end

    context "when the query is a hash" do
      it "correctly handles nil values" do
        query_string = normalizer[{:page => 1, :per_page => nil}]
        query_string.should == "page=1&per_page"
      end
    end
  end

  describe "initialization" do
    it "sets parser to HTTParty::Parser" do
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com')
      request.parser.should == HTTParty::Parser
    end

    it "sets parser to the optional parser" do
      my_parser = lambda {}
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com', :parser => my_parser)
      request.parser.should == my_parser
    end

    it "sets connection_adapter to HTTPParty::ConnectionAdapter" do
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com')
      request.connection_adapter.should == HTTParty::ConnectionAdapter
    end

    it "sets connection_adapter to the optional connection_adapter" do
      my_adapter = lambda {}
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com', :connection_adapter => my_adapter)
      request.connection_adapter.should == my_adapter
    end
  end

  describe "#format" do
    context "request yet to be made" do
      it "returns format option" do
        request = HTTParty::Request.new 'get', '/', :format => :xml
        request.format.should == :xml
      end

      it "returns nil format" do
        request = HTTParty::Request.new 'get', '/'
        request.format.should be_nil
      end
    end

    context "request has been made" do
      it "returns format option" do
        request = HTTParty::Request.new 'get', '/', :format => :xml
        request.last_response = stub
        request.format.should == :xml
      end

      it "returns the content-type from the last response when the option is not set" do
        request = HTTParty::Request.new 'get', '/'
        response = stub
        response.should_receive(:[]).with('content-type').and_return('text/json')
        request.last_response = response
        request.format.should == :json
      end
    end

  end

  context "options" do
    it "should use basic auth when configured" do
      @request.options[:basic_auth] = {:username => 'foobar', :password => 'secret'}
      @request.send(:setup_raw_request)
      @request.instance_variable_get(:@raw_request)['authorization'].should_not be_nil
    end

    it "should use digest auth when configured" do
      FakeWeb.register_uri(:get, "http://api.foo.com/v1",
        :www_authenticate => 'Digest realm="Log Viewer", qop="auth", nonce="2CA0EC6B0E126C4800E56BA0C0003D3C", opaque="5ccc069c403ebaf9f0171e9517f40e41", stale=false')

      @request.options[:digest_auth] = {:username => 'foobar', :password => 'secret'}
      @request.send(:setup_raw_request)

      raw_request = @request.instance_variable_get(:@raw_request)
      raw_request.instance_variable_get(:@header)['Authorization'].should_not be_nil
    end

    it "should use the right http method for digest authentication" do
      @post_request = HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :format => :xml)
      FakeWeb.register_uri(:post, "http://api.foo.com/v1", {})

      http = @post_request.send(:http)
      @post_request.should_receive(:http).and_return(http)
      http.should_not_receive(:head).and_return({'www-authenticate' => nil})
      @post_request.options[:digest_auth] = {:username => 'foobar', :password => 'secret'}
      @post_request.send(:setup_raw_request)
    end
  end

  describe "#uri" do
    context "query strings" do
      it "does not add an empty query string when default_params are blank" do
        @request.options[:default_params] = {}
        @request.uri.query.should be_nil
      end

      it "respects the query string normalization proc" do
        empty_proc = lambda {|qs| ""}
        @request.options[:query_string_normalizer] = empty_proc
        @request.options[:query] = {:foo => :bar}
        URI.unescape(@request.uri.query).should == ""
      end

      it "does not duplicate query string parameters when uri is called twice" do
        @request.options[:query] = {:foo => :bar}
        @request.uri
        @request.uri.query.should == "foo=bar"
      end

      context "when representing an array" do
        it "returns a Rails style query string" do
          @request.options[:query] = {:foo => %w(bar baz)}
          URI.unescape(@request.uri.query).should == "foo[]=bar&foo[]=baz"
        end
      end

    end
  end

  describe "#setup_raw_request" do
    context "when query_string_normalizer is set" do
      it "sets the body to the return value of the proc" do
        @request.options[:query_string_normalizer] = HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER
        @request.options[:body] = {:page => 1, :foo => %w(bar baz)}
        @request.send(:setup_raw_request)
        body = @request.instance_variable_get(:@raw_request).body
        URI.unescape(body).should == "foo=bar&foo=baz&page=1"
      end
    end
  end

  describe 'http' do
    it "should get a connection from the connection_adapter" do
      http = Net::HTTP.new('google.com')
      adapter = mock('adapter')
      request = HTTParty::Request.new(Net::HTTP::Get, 'https://api.foo.com/v1:443', :connection_adapter => adapter)
      adapter.should_receive(:call).with(request.uri, request.options).and_return(http)
      request.send(:http).should be http
    end
  end

  describe '#format_from_mimetype' do
    it 'should handle text/xml' do
      ["text/xml", "text/xml; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :xml
      end
    end

    it 'should handle application/xml' do
      ["application/xml", "application/xml; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :xml
      end
    end

    it 'should handle text/json' do
      ["text/json", "text/json; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :json
      end
    end

    it 'should handle application/json' do
      ["application/json", "application/json; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :json
      end
    end

    it 'should handle text/javascript' do
      ["text/javascript", "text/javascript; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :plain
      end
    end

    it 'should handle application/javascript' do
      ["application/javascript", "application/javascript; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :plain
      end
    end

    it "returns nil for an unrecognized mimetype" do
      @request.send(:format_from_mimetype, "application/atom+xml").should be_nil
    end

    it "returns nil when using a default parser" do
      @request.options[:parser] = lambda {}
      @request.send(:format_from_mimetype, "text/json").should be_nil
    end
  end

  describe 'parsing responses' do
    it 'should handle xml automatically' do
      xml = %q[<books><book><id>1234</id><name>Foo Bar!</name></book></books>]
      @request.options[:format] = :xml
      @request.send(:parse_response, xml).should == {'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}}
    end

    it 'should handle json automatically' do
      json = %q[{"books": {"book": {"name": "Foo Bar!", "id": "1234"}}}]
      @request.options[:format] = :json
      @request.send(:parse_response, json).should == {'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}}
    end

    it "should include any HTTP headers in the returned response" do
      @request.options[:format] = :html
      response = stub_response "Content"
      response.initialize_http_header("key" => "value")

      @request.perform.headers.should == { "key" => ["value"] }
    end

    if "".respond_to?(:encoding)

      it "should process charset in content type properly" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-8")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-8")
      end

      it "should process charset in content type properly if it has a different case" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;CHARSET = utf-8")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-8")
      end

      it "should process quoted charset in content type properly" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = \"utf-8\"")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-8")
      end

      it "should process utf-16 charset with little endian bom correctly" do
        @request.options[:assume_utf16_is_big_endian] = true

        response = stub_response "\xFF\xFEC\x00o\x00n\x00t\x00e\x00n\x00t\x00"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-16LE")
      end

      it "should process utf-16 charset with big endian bom correctly" do
        @request.options[:assume_utf16_is_big_endian] = false

        response = stub_response "\xFE\xFF\x00C\x00o\x00n\x00t\x00e\x00n\x00t"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-16BE")
      end

      it "should assume utf-16 little endian if options has been chosen" do
        @request.options[:assume_utf16_is_big_endian] = false

        response = stub_response "C\x00o\x00n\x00t\x00e\x00n\x00t\x00"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        resp.body.encoding.should == Encoding.find("UTF-16LE")
      end


      it "should perform no encoding if the charset is not available" do

        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-lols")
        resp = @request.perform
        resp.body.should == "Content"
        resp.body.encoding.should == "Content".encoding
      end

      it "should perform no encoding if the content type is specified but no charset is specified" do

        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain")
        resp = @request.perform
        resp.body.should == "Content"
        resp.body.encoding.should == "Content".encoding
      end
    end


    describe 'with non-200 responses' do
      context "3xx responses" do
        it 'returns a valid object for 304 not modified' do
          stub_response '', 304
          resp = @request.perform
          resp.code.should == 304
          resp.body.should == ''
          resp.should be_nil
        end

        it "redirects if a 300 contains a location header" do
          redirect = stub_response '', 300
          redirect['location'] = 'http://foo.com/foo'
          ok = stub_response('<hash><foo>bar</foo></hash>', 200)
          @http.stub!(:request).and_return(redirect, ok)
          response = @request.perform
          response.request.base_uri.to_s.should == "http://foo.com"
          response.request.path.to_s.should == "http://foo.com/foo"
          response.request.uri.request_uri.should == "/foo"
          response.request.uri.to_s.should == "http://foo.com/foo"
          response.should == {"hash" => {"foo" => "bar"}}
        end

        it "calls block given to perform with each redirect" do
          @request = HTTParty::Request.new(Net::HTTP::Get, 'http://test.com/redirect', :format => :xml)
          FakeWeb.register_uri(:get, "http://test.com/redirect", :status => [300, "REDIRECT"], :location => "http://api.foo.com/v2")
          FakeWeb.register_uri(:get, "http://api.foo.com/v2", :body => "<hash><foo>bar</foo></hash>")
          body = ""
          response = @request.perform { |chunk| body += chunk }
          body.length.should == 27
        end

        it "redirects if a 300 contains a relative location header" do
          redirect = stub_response '', 300
          redirect['location'] = '/foo/bar'
          ok = stub_response('<hash><foo>bar</foo></hash>', 200)
          @http.stub!(:request).and_return(redirect, ok)
          response = @request.perform
          response.request.base_uri.to_s.should == "http://api.foo.com"
          response.request.path.to_s.should == "/foo/bar"
          response.request.uri.request_uri.should == "/foo/bar"
          response.request.uri.to_s.should == "http://api.foo.com/foo/bar"
          response.should == {"hash" => {"foo" => "bar"}}
        end

        it "handles multiple redirects and relative location headers on different hosts" do
          @request = HTTParty::Request.new(Net::HTTP::Get, 'http://test.com/redirect', :format => :xml)
          FakeWeb.register_uri(:get, "http://test.com/redirect", :status => [300, "REDIRECT"], :location => "http://api.foo.com/v2")
          FakeWeb.register_uri(:get, "http://api.foo.com/v2", :status => [300, "REDIRECT"], :location => "/v3")
          FakeWeb.register_uri(:get, "http://api.foo.com/v3", :body => "<hash><foo>bar</foo></hash>")
          response = @request.perform
          response.request.base_uri.to_s.should == "http://api.foo.com"
          response.request.path.to_s.should == "/v3"
          response.request.uri.request_uri.should == "/v3"
          response.request.uri.to_s.should == "http://api.foo.com/v3"
          response.should == {"hash" => {"foo" => "bar"}}
        end

        it "returns the HTTParty::Response when the 300 does not contain a location header" do
          stub_response '', 300
          HTTParty::Response.should === @request.perform
        end
      end

      it 'should return a valid object for 4xx response' do
        stub_response '<foo><bar>yes</bar></foo>', 401
        resp = @request.perform
        resp.code.should == 401
        resp.body.should == "<foo><bar>yes</bar></foo>"
        resp['foo']['bar'].should == "yes"
      end

      it 'should return a valid object for 5xx response' do
        stub_response '<foo><bar>error</bar></foo>', 500
        resp = @request.perform
        resp.code.should == 500
        resp.body.should == "<foo><bar>error</bar></foo>"
        resp['foo']['bar'].should == "error"
      end

      it "parses response lazily so codes can be checked prior" do
        stub_response 'not xml', 500
        @request.options[:format] = :xml
        lambda {
          response = @request.perform
          response.code.should == 500
          response.body.should == 'not xml'
        }.should_not raise_error
      end
    end
  end

  it "should not attempt to parse empty responses" do
    [204, 304].each do |code|
      stub_response "", code

      @request.options[:format] = :xml
      @request.perform.should be_nil
    end
  end

  it "should not fail for missing mime type" do
    stub_response "Content for you"
    @request.options[:format] = :html
    @request.perform.should == 'Content for you'
  end

  describe "a request that redirects" do
    before(:each) do
      @redirect = stub_response("", 302)
      @redirect['location'] = '/foo'

      @ok = stub_response('<hash><foo>bar</foo></hash>', 200)
    end

    describe "once" do
      before(:each) do
        @http.stub!(:request).and_return(@redirect, @ok)
      end

      it "should be handled by GET transparently" do
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by POST transparently" do
        @request.http_method = Net::HTTP::Post
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by DELETE transparently" do
        @request.http_method = Net::HTTP::Delete
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by MOVE transparently" do
        @request.http_method = Net::HTTP::Move
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by COPY transparently" do
        @request.http_method = Net::HTTP::Copy
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by PATCH transparently" do
        @request.http_method = Net::HTTP::Patch
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by PUT transparently" do
        @request.http_method = Net::HTTP::Put
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by HEAD transparently" do
        @request.http_method = Net::HTTP::Head
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should be handled by OPTIONS transparently" do
        @request.http_method = Net::HTTP::Options
        @request.perform.should == {"hash" => {"foo" => "bar"}}
      end

      it "should keep track of cookies between redirects" do
        @redirect['Set-Cookie'] = 'foo=bar; name=value; HTTPOnly'
        @request.perform
        @request.options[:headers]['Cookie'].should match(/foo=bar/)
        @request.options[:headers]['Cookie'].should match(/name=value/)
      end

      it 'should update cookies with rediects' do
        @request.options[:headers] = {'Cookie'=> 'foo=bar;'}
        @redirect['Set-Cookie'] = 'foo=tar;'
        @request.perform
        @request.options[:headers]['Cookie'].should match(/foo=tar/)
      end

      it 'should keep cookies between rediects' do
        @request.options[:headers] = {'Cookie'=> 'keep=me'}
        @redirect['Set-Cookie'] = 'foo=tar;'
        @request.perform
        @request.options[:headers]['Cookie'].should match(/keep=me/)
      end

      it "should handle multiple Set-Cookie headers between redirects" do
        @redirect.add_field 'set-cookie', 'foo=bar; name=value; HTTPOnly'
        @redirect.add_field 'set-cookie', 'one=1; two=2; HTTPOnly'
        @request.perform
        @request.options[:headers]['Cookie'].should match(/foo=bar/)
        @request.options[:headers]['Cookie'].should match(/name=value/)
        @request.options[:headers]['Cookie'].should match(/one=1/)
        @request.options[:headers]['Cookie'].should match(/two=2/)
      end

      it 'should make resulting request a get request if it not already' do
        @request.http_method = Net::HTTP::Delete
        @request.perform.should == {"hash" => {"foo" => "bar"}}
        @request.http_method.should == Net::HTTP::Get
      end

      it 'should not make resulting request a get request if options[:maintain_method_across_redirects] is true' do
        @request.options[:maintain_method_across_redirects] = true
        @request.http_method = Net::HTTP::Delete
        @request.perform.should == {"hash" => {"foo" => "bar"}}
        @request.http_method.should == Net::HTTP::Delete
      end

      it 'should log the redirection' do
        logger_double = double
        logger_double.should_receive(:info).twice
        @request.options[:logger] = logger_double
        @request.perform
      end
    end

    describe "infinitely" do
      before(:each) do
        @http.stub!(:request).and_return(@redirect)
      end

      it "should raise an exception" do
        lambda { @request.perform }.should raise_error(HTTParty::RedirectionTooDeep)
      end
    end
  end

  describe "#handle_deflation" do
    context "context-encoding" do
      before do
        @request.options[:format] = :html
        @last_response = mock()
        @last_response.stub!(:body).and_return('')
      end

      it "should inflate the gzipped body with content-encoding: gzip" do
        @last_response.stub!(:[]).with("content-encoding").and_return("gzip")
        @request.stub!(:last_response).and_return(@last_response)
        Zlib::GzipReader.should_receive(:new).and_return(StringIO.new(''))
        @request.last_response.should_receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end

      it "should inflate the gzipped body with content-encoding: x-gzip" do
        @last_response.stub!(:[]).with("content-encoding").and_return("x-gzip")
        @request.stub!(:last_response).and_return(@last_response)
        Zlib::GzipReader.should_receive(:new).and_return(StringIO.new(''))
        @request.last_response.should_receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end

      it "should inflate the deflated body" do
        @last_response.stub!(:[]).with("content-encoding").and_return("deflate")
        @request.stub!(:last_response).and_return(@last_response)
        Zlib::Inflate.should_receive(:inflate).and_return('')
        @request.last_response.should_receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end
    end
  end

  context "with POST http method" do
    it "should raise argument error if query is not a hash" do
      lambda {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :format => :xml, :query => 'astring').perform
      }.should raise_error(ArgumentError)
    end
  end

  describe "argument validation" do
    it "should raise argument error if basic_auth and digest_auth are both present" do
      lambda {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :basic_auth => {}, :digest_auth => {}).perform
      }.should raise_error(ArgumentError, "only one authentication method, :basic_auth or :digest_auth may be used at a time")
    end

    it "should raise argument error if basic_auth is not a hash" do
      lambda {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :basic_auth => ["foo", "bar"]).perform
      }.should raise_error(ArgumentError, ":basic_auth must be a hash")
    end

    it "should raise argument error if digest_auth is not a hash" do
      lambda {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :digest_auth => ["foo", "bar"]).perform
      }.should raise_error(ArgumentError, ":digest_auth must be a hash")
    end
  end
end
