require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe HTTParty::Request do
  before do
    @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', format: :xml)
  end

  describe "::NON_RAILS_QUERY_STRING_NORMALIZER" do
    let(:normalizer) { HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER }

    it "doesn't modify strings" do
      query_string = normalizer["foo=bar&foo=baz"]
      expect(CGI.unescape(query_string)).to eq("foo=bar&foo=baz")
    end

    context "when the query is an array" do
      it "doesn't include brackets" do
        query_string = normalizer[{page: 1, foo: %w(bar baz)}]
        expect(CGI.unescape(query_string)).to eq("foo=bar&foo=baz&page=1")
      end

      it "URI encodes array values" do
        query_string = normalizer[{people: ["Otis Redding", "Bob Marley", "Tim & Jon"], page: 1, xyzzy: 3}]
        expect(query_string).to eq("page=1&people=Otis%20Redding&people=Bob%20Marley&people=Tim%20%26%20Jon&xyzzy=3")
      end
    end

    context "when the query is a hash" do
      it "correctly handles nil values" do
        query_string = normalizer[{page: 1, per_page: nil}]
        expect(query_string).to eq("page=1&per_page")
      end
    end
  end

  describe "initialization" do
    it "sets parser to HTTParty::Parser" do
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com')
      expect(request.parser).to eq(HTTParty::Parser)
    end

    it "sets parser to the optional parser" do
      my_parser = lambda {}
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com', parser: my_parser)
      expect(request.parser).to eq(my_parser)
    end

    it "sets connection_adapter to HTTPParty::ConnectionAdapter" do
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com')
      expect(request.connection_adapter).to eq(HTTParty::ConnectionAdapter)
    end

    it "sets connection_adapter to the optional connection_adapter" do
      my_adapter = lambda {}
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://google.com', connection_adapter: my_adapter)
      expect(request.connection_adapter).to eq(my_adapter)
    end

    context "when basic authentication credentials provided in uri" do
      context "when basic auth options wasn't set explicitly" do
        it "sets basic auth from uri" do
          request = HTTParty::Request.new(Net::HTTP::Get, 'http://user1:pass1@example.com')
          expect(request.options[:basic_auth]).to eq({username: 'user1', password: 'pass1'})
        end
      end

      context "when basic auth options was set explicitly" do
        it "uses basic auth from url anyway" do
          basic_auth = {username: 'user2', password: 'pass2'}
          request = HTTParty::Request.new(Net::HTTP::Get, 'http://user1:pass1@example.com', basic_auth: basic_auth)
          expect(request.options[:basic_auth]).to eq({username: 'user1', password: 'pass1'})
        end
      end
    end
  end

  describe "#format" do
    context "request yet to be made" do
      it "returns format option" do
        request = HTTParty::Request.new 'get', '/', format: :xml
        expect(request.format).to eq(:xml)
      end

      it "returns nil format" do
        request = HTTParty::Request.new 'get', '/'
        expect(request.format).to be_nil
      end
    end

    context "request has been made" do
      it "returns format option" do
        request = HTTParty::Request.new 'get', '/', format: :xml
        request.last_response = double
        expect(request.format).to eq(:xml)
      end

      it "returns the content-type from the last response when the option is not set" do
        request = HTTParty::Request.new 'get', '/'
        response = double
        expect(response).to receive(:[]).with('content-type').and_return('text/json')
        request.last_response = response
        expect(request.format).to eq(:json)
      end
    end
  end

  context "options" do
    it "should use basic auth when configured" do
      @request.options[:basic_auth] = {username: 'foobar', password: 'secret'}
      @request.send(:setup_raw_request)
      expect(@request.instance_variable_get(:@raw_request)['authorization']).not_to be_nil
    end

    it "should use digest auth when configured" do
      FakeWeb.register_uri(:get, "http://api.foo.com/v1",
                           www_authenticate: 'Digest realm="Log Viewer", qop="auth", nonce="2CA0EC6B0E126C4800E56BA0C0003D3C", opaque="5ccc069c403ebaf9f0171e9517f40e41", stale=false')

      @request.options[:digest_auth] = {username: 'foobar', password: 'secret'}
      @request.send(:setup_raw_request)

      raw_request = @request.instance_variable_get(:@raw_request)
      expect(raw_request.instance_variable_get(:@header)['Authorization']).not_to be_nil
    end

    it "should use the right http method for digest authentication" do
      @post_request = HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', format: :xml)
      FakeWeb.register_uri(:post, "http://api.foo.com/v1", {})

      http = @post_request.send(:http)
      expect(@post_request).to receive(:http).and_return(http)
      expect(http).not_to receive(:head).with({'www-authenticate' => nil})
      @post_request.options[:digest_auth] = {username: 'foobar', password: 'secret'}
      @post_request.send(:setup_raw_request)
    end

    it 'should maintain cookies returned from setup_digest_auth' do
      FakeWeb.register_uri(
        :get, "http://api.foo.com/v1",
        set_cookie: 'custom-cookie=1234567',
        www_authenticate: 'Digest realm="Log Viewer", qop="auth", nonce="2CA0EC6B0E126C4800E56BA0C0003D3C", opaque="5ccc069c403ebaf9f0171e9517f40e41", stale=false'
      )

      @request.options[:digest_auth] = {username: 'foobar', password: 'secret'}
      @request.send(:setup_raw_request)

      raw_request = @request.instance_variable_get(:@raw_request)
      expect(raw_request.instance_variable_get(:@header)['cookie']).to eql ["custom-cookie=1234567"]
    end

    it 'should merge cookies from setup_digest_auth and request' do
      FakeWeb.register_uri(
        :get, "http://api.foo.com/v1",
        set_cookie: 'custom-cookie=1234567',
        www_authenticate: 'Digest realm="Log Viewer", qop="auth", nonce="2CA0EC6B0E126C4800E56BA0C0003D3C", opaque="5ccc069c403ebaf9f0171e9517f40e41", stale=false'
      )

      @request.options[:digest_auth] = {username: 'foobar', password: 'secret'}
      @request.options[:headers] = {'cookie' => 'request-cookie=test'}
      @request.send(:setup_raw_request)

      raw_request = @request.instance_variable_get(:@raw_request)
      expect(raw_request.instance_variable_get(:@header)['cookie']).to eql ['request-cookie=test', 'custom-cookie=1234567']
    end

    it 'should use body_stream when configured' do
      stream = StringIO.new('foo')
      request = HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', body_stream: stream)
      request.send(:setup_raw_request)
      expect(request.instance_variable_get(:@raw_request).body_stream).to eq(stream)
    end
  end

  describe "#uri" do
    context "redirects" do
      it "returns correct path when the server sets the location header to a filename" do
        @request.last_uri = URI.parse("http://example.com/foo/bar")
        @request.path = URI.parse("bar?foo=bar")
        @request.redirect = true

        expect(@request.uri).to eq(URI.parse("http://example.com/foo/bar?foo=bar"))
      end

      context "location header is an absolute path" do
        it "returns correct path when location has leading slash" do
          @request.last_uri = URI.parse("http://example.com/foo/bar")
          @request.path = URI.parse("/bar?foo=bar")
          @request.redirect = true

          expect(@request.uri).to eq(URI.parse("http://example.com/bar?foo=bar"))
        end

        it "returns the correct path when location has no leading slash" do
          @request.last_uri = URI.parse("http://example.com")
          @request.path = URI.parse("bar/")
          @request.redirect = true

          expect(@request.uri).to eq(URI.parse("http://example.com/bar/"))
        end
      end
      it "returns correct path when the server sets the location header to a full uri" do
        @request.last_uri = URI.parse("http://example.com/foo/bar")
        @request.path = URI.parse("http://example.com/bar?foo=bar")
        @request.redirect = true

        expect(@request.uri).to eq(URI.parse("http://example.com/bar?foo=bar"))
      end
    end

    context "query strings" do
      it "does not add an empty query string when default_params are blank" do
        @request.options[:default_params] = {}
        expect(@request.uri.query).to be_nil
      end

      it "respects the query string normalization proc" do
        empty_proc = lambda {|qs| ""}
        @request.options[:query_string_normalizer] = empty_proc
        @request.options[:query] = {foo: :bar}
        expect(CGI.unescape(@request.uri.query)).to eq("")
      end

      it "does not append an ampersand when queries are embedded in paths" do
        @request.path = "/path?a=1"
        @request.options[:query] = {}
        expect(@request.uri.query).to eq("a=1")
      end

      it "does not duplicate query string parameters when uri is called twice" do
        @request.options[:query] = {foo: :bar}
        @request.uri
        expect(@request.uri.query).to eq("foo=bar")
      end

      context "when representing an array" do
        it "returns a Rails style query string" do
          @request.options[:query] = {foo: %w(bar baz)}
          expect(CGI.unescape(@request.uri.query)).to eq("foo[]=bar&foo[]=baz")
        end
      end
    end
  end

  describe "#setup_raw_request" do
    context "when query_string_normalizer is set" do
      it "sets the body to the return value of the proc" do
        @request.options[:query_string_normalizer] = HTTParty::Request::NON_RAILS_QUERY_STRING_NORMALIZER
        @request.options[:body] = {page: 1, foo: %w(bar baz)}
        @request.send(:setup_raw_request)
        body = @request.instance_variable_get(:@raw_request).body
        expect(CGI.unescape(body)).to eq("foo=bar&foo=baz&page=1")
      end
    end
  end

  describe 'http' do
    it "should get a connection from the connection_adapter" do
      http = Net::HTTP.new('google.com')
      adapter = double('adapter')
      request = HTTParty::Request.new(Net::HTTP::Get, 'https://api.foo.com/v1:443', connection_adapter: adapter)
      expect(adapter).to receive(:call).with(request.uri, request.options).and_return(http)
      expect(request.send(:http)).to be http
    end
  end

  describe '#format_from_mimetype' do
    it 'should handle text/xml' do
      ["text/xml", "text/xml; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:xml)
      end
    end

    it 'should handle application/xml' do
      ["application/xml", "application/xml; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:xml)
      end
    end

    it 'should handle text/json' do
      ["text/json", "text/json; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:json)
      end
    end

    it 'should handle application/json' do
      ["application/json", "application/json; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:json)
      end
    end

    it 'should handle text/csv' do
      ["text/csv", "text/csv; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:csv)
      end
    end

    it 'should handle application/csv' do
      ["application/csv", "application/csv; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:csv)
      end
    end

    it 'should handle text/comma-separated-values' do
      ["text/comma-separated-values", "text/comma-separated-values; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:csv)
      end
    end

    it 'should handle text/javascript' do
      ["text/javascript", "text/javascript; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:plain)
      end
    end

    it 'should handle application/javascript' do
      ["application/javascript", "application/javascript; charset=iso8859-1"].each do |ct|
        expect(@request.send(:format_from_mimetype, ct)).to eq(:plain)
      end
    end

    it "returns nil for an unrecognized mimetype" do
      expect(@request.send(:format_from_mimetype, "application/atom+xml")).to be_nil
    end

    it "returns nil when using a default parser" do
      @request.options[:parser] = lambda {}
      expect(@request.send(:format_from_mimetype, "text/json")).to be_nil
    end
  end

  describe 'parsing responses' do
    it 'should handle xml automatically' do
      xml = '<books><book><id>1234</id><name>Foo Bar!</name></book></books>'
      @request.options[:format] = :xml
      expect(@request.send(:parse_response, xml)).to eq({'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}})
    end

    it 'should handle csv automatically' do
      csv = ['"id","Name"', '"1234","Foo Bar!"'].join("\n")
      @request.options[:format] = :csv
      expect(@request.send(:parse_response, csv)).to eq([%w(id Name), ["1234", "Foo Bar!"]])
    end

    it 'should handle json automatically' do
      json = '{"books": {"book": {"name": "Foo Bar!", "id": "1234"}}}'
      @request.options[:format] = :json
      expect(@request.send(:parse_response, json)).to eq({'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}})
    end

    it "should include any HTTP headers in the returned response" do
      @request.options[:format] = :html
      response = stub_response "Content"
      response.initialize_http_header("key" => "value")

      expect(@request.perform.headers).to eq({ "key" => ["value"] })
    end

    if "".respond_to?(:encoding)

      it "should process charset in content type properly" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-8")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-8"))
      end

      it "should process charset in content type properly if it has a different case" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;CHARSET = utf-8")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-8"))
      end

      it "should process quoted charset in content type properly" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = \"utf-8\"")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-8"))
      end

      it "should process utf-16 charset with little endian bom correctly" do
        @request.options[:assume_utf16_is_big_endian] = true

        response = stub_response "\xFF\xFEC\x00o\x00n\x00t\x00e\x00n\x00t\x00"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-16LE"))
      end

      it "should process utf-16 charset with big endian bom correctly" do
        @request.options[:assume_utf16_is_big_endian] = false

        response = stub_response "\xFE\xFF\x00C\x00o\x00n\x00t\x00e\x00n\x00t"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-16BE"))
      end

      it "should assume utf-16 little endian if options has been chosen" do
        @request.options[:assume_utf16_is_big_endian] = false

        response = stub_response "C\x00o\x00n\x00t\x00e\x00n\x00t\x00"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-16")
        resp = @request.perform
        expect(resp.body.encoding).to eq(Encoding.find("UTF-16LE"))
      end

      it "should perform no encoding if the charset is not available" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain;charset = utf-lols")
        resp = @request.perform
        expect(resp.body).to eq("Content")
        expect(resp.body.encoding).to eq("Content".encoding)
      end

      it "should perform no encoding if the content type is specified but no charset is specified" do
        response = stub_response "Content"
        response.initialize_http_header("Content-Type" => "text/plain")
        resp = @request.perform
        expect(resp.body).to eq("Content")
        expect(resp.body.encoding).to eq("Content".encoding)
      end
    end

    describe 'with non-200 responses' do
      context "3xx responses" do
        it 'returns a valid object for 304 not modified' do
          stub_response '', 304
          resp = @request.perform
          expect(resp.code).to eq(304)
          expect(resp.body).to eq('')
          expect(resp).to be_nil
        end

        it "redirects if a 300 contains a location header" do
          redirect = stub_response '', 300
          redirect['location'] = 'http://foo.com/foo'
          ok = stub_response('<hash><foo>bar</foo></hash>', 200)
          allow(@http).to receive(:request).and_return(redirect, ok)
          response = @request.perform
          expect(response.request.base_uri.to_s).to eq("http://foo.com")
          expect(response.request.path.to_s).to eq("http://foo.com/foo")
          expect(response.request.uri.request_uri).to eq("/foo")
          expect(response.request.uri.to_s).to eq("http://foo.com/foo")
          expect(response.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "calls block given to perform with each redirect" do
          @request = HTTParty::Request.new(Net::HTTP::Get, 'http://test.com/redirect', format: :xml)
          FakeWeb.register_uri(:get, "http://test.com/redirect", status: [300, "REDIRECT"], location: "http://api.foo.com/v2")
          FakeWeb.register_uri(:get, "http://api.foo.com/v2", body: "<hash><foo>bar</foo></hash>")
          body = ""
          response = @request.perform { |chunk| body += chunk }
          expect(body.length).to eq(27)
        end

        it "redirects if a 300 contains a relative location header" do
          redirect = stub_response '', 300
          redirect['location'] = '/foo/bar'
          ok = stub_response('<hash><foo>bar</foo></hash>', 200)
          allow(@http).to receive(:request).and_return(redirect, ok)
          response = @request.perform
          expect(response.request.base_uri.to_s).to eq("http://api.foo.com")
          expect(response.request.path.to_s).to eq("/foo/bar")
          expect(response.request.uri.request_uri).to eq("/foo/bar")
          expect(response.request.uri.to_s).to eq("http://api.foo.com/foo/bar")
          expect(response.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "handles multiple redirects and relative location headers on different hosts" do
          @request = HTTParty::Request.new(Net::HTTP::Get, 'http://test.com/redirect', format: :xml)
          FakeWeb.register_uri(:get, "http://test.com/redirect", status: [300, "REDIRECT"], location: "http://api.foo.com/v2")
          FakeWeb.register_uri(:get, "http://api.foo.com/v2", status: [300, "REDIRECT"], location: "/v3")
          FakeWeb.register_uri(:get, "http://api.foo.com/v3", body: "<hash><foo>bar</foo></hash>")
          response = @request.perform
          expect(response.request.base_uri.to_s).to eq("http://api.foo.com")
          expect(response.request.path.to_s).to eq("/v3")
          expect(response.request.uri.request_uri).to eq("/v3")
          expect(response.request.uri.to_s).to eq("http://api.foo.com/v3")
          expect(response.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "returns the HTTParty::Response when the 300 does not contain a location header" do
          stub_response '', 300
          expect(HTTParty::Response).to be === @request.perform
        end

        it "redirects including port" do
          FakeWeb.register_uri(:get, "http://withport.com:3000/v1", status: [301, "Moved Permanently"], location: "http://withport.com:3000/v2")
          FakeWeb.register_uri(:get, "http://withport.com:3000/v2", status: 200)
          request = HTTParty::Request.new(Net::HTTP::Get, 'http://withport.com:3000/v1')
          response = request.perform
          expect(response.request.base_uri.to_s).to eq("http://withport.com:3000")
        end
      end

      it 'should return a valid object for 4xx response' do
        stub_response '<foo><bar>yes</bar></foo>', 401
        resp = @request.perform
        expect(resp.code).to eq(401)
        expect(resp.body).to eq("<foo><bar>yes</bar></foo>")
        expect(resp['foo']['bar']).to eq("yes")
      end

      it 'should return a valid object for 5xx response' do
        stub_response '<foo><bar>error</bar></foo>', 500
        resp = @request.perform
        expect(resp.code).to eq(500)
        expect(resp.body).to eq("<foo><bar>error</bar></foo>")
        expect(resp['foo']['bar']).to eq("error")
      end

      it "parses response lazily so codes can be checked prior" do
        stub_response 'not xml', 500
        @request.options[:format] = :xml
        expect {
          response = @request.perform
          expect(response.code).to eq(500)
          expect(response.body).to eq('not xml')
        }.not_to raise_error
      end
    end
  end

  it "should not attempt to parse empty responses" do
    [204, 304].each do |code|
      stub_response "", code

      @request.options[:format] = :xml
      expect(@request.perform).to be_nil
    end
  end

  it "should not fail for missing mime type" do
    stub_response "Content for you"
    @request.options[:format] = :html
    expect(@request.perform.parsed_response).to eq('Content for you')
  end

  [300, 301, 302, 305].each do |code|
    describe "a request that #{code} redirects" do
      before(:each) do
        @redirect = stub_response("", code)
        @redirect['location'] = '/foo'

        @ok = stub_response('<hash><foo>bar</foo></hash>', 200)
      end

      describe "once" do
        before(:each) do
          allow(@http).to receive(:request).and_return(@redirect, @ok)
        end

        it "should be handled by GET transparently" do
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by POST transparently" do
          @request.http_method = Net::HTTP::Post
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by DELETE transparently" do
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by MOVE transparently" do
          @request.http_method = Net::HTTP::Move
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by COPY transparently" do
          @request.http_method = Net::HTTP::Copy
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by PATCH transparently" do
          @request.http_method = Net::HTTP::Patch
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by PUT transparently" do
          @request.http_method = Net::HTTP::Put
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by HEAD transparently" do
          @request.http_method = Net::HTTP::Head
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by OPTIONS transparently" do
          @request.http_method = Net::HTTP::Options
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should keep track of cookies between redirects" do
          @redirect['Set-Cookie'] = 'foo=bar; name=value; HTTPOnly'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
          expect(@request.options[:headers]['Cookie']).to match(/name=value/)
        end

        it 'should update cookies with rediects' do
          @request.options[:headers] = {'Cookie' => 'foo=bar;'}
          @redirect['Set-Cookie'] = 'foo=tar;'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=tar/)
        end

        it 'should keep cookies between rediects' do
          @request.options[:headers] = {'Cookie' => 'keep=me'}
          @redirect['Set-Cookie'] = 'foo=tar;'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/keep=me/)
        end

        it "should handle multiple Set-Cookie headers between redirects" do
          @redirect.add_field 'set-cookie', 'foo=bar; name=value; HTTPOnly'
          @redirect.add_field 'set-cookie', 'one=1; two=2; HTTPOnly'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
          expect(@request.options[:headers]['Cookie']).to match(/name=value/)
          expect(@request.options[:headers]['Cookie']).to match(/one=1/)
          expect(@request.options[:headers]['Cookie']).to match(/two=2/)
        end

        it 'should make resulting request a get request if it not already' do
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
          expect(@request.http_method).to eq(Net::HTTP::Get)
        end

        it 'should not make resulting request a get request if options[:maintain_method_across_redirects] is true' do
          @request.options[:maintain_method_across_redirects] = true
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
          expect(@request.http_method).to eq(Net::HTTP::Delete)
        end

        it 'should log the redirection' do
          logger_double = double
          expect(logger_double).to receive(:info).twice
          @request.options[:logger] = logger_double
          @request.perform
        end
      end

      describe "infinitely" do
        before(:each) do
          allow(@http).to receive(:request).and_return(@redirect)
        end

        it "should raise an exception" do
          expect { @request.perform }.to raise_error(HTTParty::RedirectionTooDeep)
        end
      end
    end
  end

  describe "a request that 303 redirects" do
    before(:each) do
      @redirect = stub_response("", 303)
      @redirect['location'] = '/foo'

      @ok = stub_response('<hash><foo>bar</foo></hash>', 200)
    end

    describe "once" do
      before(:each) do
        allow(@http).to receive(:request).and_return(@redirect, @ok)
      end

      it "should be handled by GET transparently" do
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by POST transparently" do
        @request.http_method = Net::HTTP::Post
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by DELETE transparently" do
        @request.http_method = Net::HTTP::Delete
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by MOVE transparently" do
        @request.http_method = Net::HTTP::Move
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by COPY transparently" do
        @request.http_method = Net::HTTP::Copy
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by PATCH transparently" do
        @request.http_method = Net::HTTP::Patch
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by PUT transparently" do
        @request.http_method = Net::HTTP::Put
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by HEAD transparently" do
        @request.http_method = Net::HTTP::Head
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should be handled by OPTIONS transparently" do
        @request.http_method = Net::HTTP::Options
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
      end

      it "should keep track of cookies between redirects" do
        @redirect['Set-Cookie'] = 'foo=bar; name=value; HTTPOnly'
        @request.perform
        expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
        expect(@request.options[:headers]['Cookie']).to match(/name=value/)
      end

      it 'should update cookies with rediects' do
        @request.options[:headers] = {'Cookie' => 'foo=bar;'}
        @redirect['Set-Cookie'] = 'foo=tar;'
        @request.perform
        expect(@request.options[:headers]['Cookie']).to match(/foo=tar/)
      end

      it 'should keep cookies between rediects' do
        @request.options[:headers] = {'Cookie' => 'keep=me'}
        @redirect['Set-Cookie'] = 'foo=tar;'
        @request.perform
        expect(@request.options[:headers]['Cookie']).to match(/keep=me/)
      end

      it "should handle multiple Set-Cookie headers between redirects" do
        @redirect.add_field 'set-cookie', 'foo=bar; name=value; HTTPOnly'
        @redirect.add_field 'set-cookie', 'one=1; two=2; HTTPOnly'
        @request.perform
        expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
        expect(@request.options[:headers]['Cookie']).to match(/name=value/)
        expect(@request.options[:headers]['Cookie']).to match(/one=1/)
        expect(@request.options[:headers]['Cookie']).to match(/two=2/)
      end

      it 'should make resulting request a get request if it not already' do
        @request.http_method = Net::HTTP::Delete
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        expect(@request.http_method).to eq(Net::HTTP::Get)
      end

      it 'should make resulting request a get request if options[:maintain_method_across_redirects] is false' do
        @request.options[:maintain_method_across_redirects] = false
        @request.http_method = Net::HTTP::Delete
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        expect(@request.http_method).to eq(Net::HTTP::Get)
      end

      it 'should make resulting request a get request if options[:maintain_method_across_redirects] is true but options[:resend_on_redirect] is false' do
        @request.options[:maintain_method_across_redirects] = true
        @request.options[:resend_on_redirect] = false
        @request.http_method = Net::HTTP::Delete
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        expect(@request.http_method).to eq(Net::HTTP::Get)
      end

      it 'should not make resulting request a get request if options[:maintain_method_across_redirects] and options[:resend_on_redirect] is true' do
        @request.options[:maintain_method_across_redirects] = true
        @request.options[:resend_on_redirect] = true
        @request.http_method = Net::HTTP::Delete
        expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        expect(@request.http_method).to eq(Net::HTTP::Delete)
      end

      it 'should log the redirection' do
        logger_double = double
        expect(logger_double).to receive(:info).twice
        @request.options[:logger] = logger_double
        @request.perform
      end
    end

    describe "infinitely" do
      before(:each) do
        allow(@http).to receive(:request).and_return(@redirect)
      end

      it "should raise an exception" do
        expect { @request.perform }.to raise_error(HTTParty::RedirectionTooDeep)
      end
    end
  end

  describe "a request that returns 304" do
    before(:each) do
      @redirect = stub_response("", 304)
      @redirect['location'] = '/foo'
    end

    before(:each) do
      allow(@http).to receive(:request).and_return(@redirect)
    end

    it "should report 304 with a GET request" do
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a POST request" do
      @request.http_method = Net::HTTP::Post
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a DELETE request" do
      @request.http_method = Net::HTTP::Delete
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a MOVE request" do
      @request.http_method = Net::HTTP::Move
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a COPY request" do
      @request.http_method = Net::HTTP::Copy
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a PATCH request" do
      @request.http_method = Net::HTTP::Patch
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a PUT request" do
      @request.http_method = Net::HTTP::Put
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a HEAD request" do
      @request.http_method = Net::HTTP::Head
      expect(@request.perform.code).to eq(304)
    end

    it "should report 304 with a OPTIONS request" do
      @request.http_method = Net::HTTP::Options
      expect(@request.perform.code).to eq(304)
    end

    it 'should not log the redirection' do
      logger_double = double
      expect(logger_double).to receive(:info).once
      @request.options[:logger] = logger_double
      @request.perform
    end
  end

  [307, 308].each do |code|
    describe "a request that #{code} redirects" do
      before(:each) do
        @redirect = stub_response("", code)
        @redirect['location'] = '/foo'

        @ok = stub_response('<hash><foo>bar</foo></hash>', 200)
      end

      describe "once" do
        before(:each) do
          allow(@http).to receive(:request).and_return(@redirect, @ok)
        end

        it "should be handled by GET transparently" do
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by POST transparently" do
          @request.http_method = Net::HTTP::Post
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by DELETE transparently" do
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by MOVE transparently" do
          @request.http_method = Net::HTTP::Move
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by COPY transparently" do
          @request.http_method = Net::HTTP::Copy
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by PATCH transparently" do
          @request.http_method = Net::HTTP::Patch
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by PUT transparently" do
          @request.http_method = Net::HTTP::Put
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by HEAD transparently" do
          @request.http_method = Net::HTTP::Head
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should be handled by OPTIONS transparently" do
          @request.http_method = Net::HTTP::Options
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
        end

        it "should keep track of cookies between redirects" do
          @redirect['Set-Cookie'] = 'foo=bar; name=value; HTTPOnly'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
          expect(@request.options[:headers]['Cookie']).to match(/name=value/)
        end

        it 'should update cookies with rediects' do
          @request.options[:headers] = {'Cookie' => 'foo=bar;'}
          @redirect['Set-Cookie'] = 'foo=tar;'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=tar/)
        end

        it 'should keep cookies between rediects' do
          @request.options[:headers] = {'Cookie' => 'keep=me'}
          @redirect['Set-Cookie'] = 'foo=tar;'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/keep=me/)
        end

        it "should handle multiple Set-Cookie headers between redirects" do
          @redirect.add_field 'set-cookie', 'foo=bar; name=value; HTTPOnly'
          @redirect.add_field 'set-cookie', 'one=1; two=2; HTTPOnly'
          @request.perform
          expect(@request.options[:headers]['Cookie']).to match(/foo=bar/)
          expect(@request.options[:headers]['Cookie']).to match(/name=value/)
          expect(@request.options[:headers]['Cookie']).to match(/one=1/)
          expect(@request.options[:headers]['Cookie']).to match(/two=2/)
        end

        it 'should maintain method in resulting request' do
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
          expect(@request.http_method).to eq(Net::HTTP::Delete)
        end

        it 'should maintain method in resulting request if options[:maintain_method_across_redirects] is false' do
          @request.options[:maintain_method_across_redirects] = false
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
          expect(@request.http_method).to eq(Net::HTTP::Delete)
        end

        it 'should maintain method in resulting request if options[:maintain_method_across_redirects] is true' do
          @request.options[:maintain_method_across_redirects] = true
          @request.http_method = Net::HTTP::Delete
          expect(@request.perform.parsed_response).to eq({"hash" => {"foo" => "bar"}})
          expect(@request.http_method).to eq(Net::HTTP::Delete)
        end

        it 'should log the redirection' do
          logger_double = double
          expect(logger_double).to receive(:info).twice
          @request.options[:logger] = logger_double
          @request.perform
        end
      end

      describe "infinitely" do
        before(:each) do
          allow(@http).to receive(:request).and_return(@redirect)
        end

        it "should raise an exception" do
          expect { @request.perform }.to raise_error(HTTParty::RedirectionTooDeep)
        end
      end
    end
  end

  describe "#handle_deflation" do
    context "context-encoding" do
      before do
        @request.options[:format] = :html
        @last_response = double
        allow(@last_response).to receive(:body).and_return('')
      end

      it "should inflate the gzipped body with content-encoding: gzip" do
        allow(@last_response).to receive(:[]).with("content-encoding").and_return("gzip")
        allow(@request).to receive(:last_response).and_return(@last_response)
        expect(Zlib::GzipReader).to receive(:new).and_return(StringIO.new(''))
        expect(@request.last_response).to receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end

      it "should inflate the gzipped body with content-encoding: x-gzip" do
        allow(@last_response).to receive(:[]).with("content-encoding").and_return("x-gzip")
        allow(@request).to receive(:last_response).and_return(@last_response)
        expect(Zlib::GzipReader).to receive(:new).and_return(StringIO.new(''))
        expect(@request.last_response).to receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end

      it "should inflate the deflated body" do
        allow(@last_response).to receive(:[]).with("content-encoding").and_return("deflate")
        allow(@request).to receive(:last_response).and_return(@last_response)
        expect(Zlib::Inflate).to receive(:inflate).and_return('')
        expect(@request.last_response).to receive(:delete).with('content-encoding')
        @request.send(:handle_deflation)
      end
    end
  end

  context "with POST http method" do
    it "should raise argument error if query is not a hash" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', format: :xml, query: 'astring').perform
      }.to raise_error(ArgumentError)
    end
  end

  describe "argument validation" do
    it "should raise argument error if basic_auth and digest_auth are both present" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', basic_auth: {}, digest_auth: {}).perform
      }.to raise_error(ArgumentError, "only one authentication method, :basic_auth or :digest_auth may be used at a time")
    end

    it "should raise argument error if basic_auth is not a hash" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', basic_auth: %w(foo bar)).perform
      }.to raise_error(ArgumentError, ":basic_auth must be a hash")
    end

    it "should raise argument error if digest_auth is not a hash" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', digest_auth: %w(foo bar)).perform
      }.to raise_error(ArgumentError, ":digest_auth must be a hash")
    end

    it "should raise argument error if headers is not a hash" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', headers: %w(foo bar)).perform
      }.to raise_error(ArgumentError, ":headers must be a hash")
    end

    it "should raise argument error if options method is not http accepted method" do
      expect {
        HTTParty::Request.new('SuperPost', 'http://api.foo.com/v1').perform
      }.to raise_error(ArgumentError, "only get, post, patch, put, delete, head, and options methods are supported")
    end

    it "should raise argument error if http method is post and query is not hash" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', query: "message: hello").perform
      }.to raise_error(ArgumentError, ":query must be hash if using HTTP Post")
    end

    it "should raise RedirectionTooDeep error if limit is negative" do
      expect {
        HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', limit: -1).perform
      }.to raise_error(HTTParty::RedirectionTooDeep, 'HTTP redirects too deep')
    end
  end
end
