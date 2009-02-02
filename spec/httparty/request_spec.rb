require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe HTTParty::Request do
  def stub_response(body, code = 200)
    unless @http
      @http = Net::HTTP.new('localhost', 80)
      @request.stub!(:http).and_return(@http)
      @request.stub!(:uri).and_return(URI.parse("http://foo.com/foobar"))
    end

    response = Net::HTTPResponse::CODE_TO_OBJ[code.to_s].new("1.1", code, body)
    response.stub!(:body).and_return(body)

    @http.stub!(:request).and_return(response)
    response
  end

  before do
    @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', :format => :xml)
  end
  
  describe "#format" do
    it "should return the correct parsing format" do
      @request.format.should == :xml
    end
  end

  describe 'http' do
    it "should use ssl for port 443" do
      request = HTTParty::Request.new(Net::HTTP::Get, 'https://api.foo.com/v1:443')
      request.send(:http).use_ssl?.should == true
    end
    
    it 'should not use ssl for port 80' do
      request = HTTParty::Request.new(Net::HTTP::Get, 'http://foobar.com')
      @request.send(:http).use_ssl?.should == false
    end

    it "should use basic auth when configured" do
      @request.options[:basic_auth] = {:username => 'foobar', :password => 'secret'}
      @request.send(:setup_raw_request)
      @request.instance_variable_get(:@raw_request)['authorization'].should_not be_nil
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
        @request.send(:format_from_mimetype, ct).should == :json
      end
    end

    it 'should handle application/javascript' do
      ["application/javascript", "application/javascript; charset=iso8859-1"].each do |ct|
        @request.send(:format_from_mimetype, ct).should == :json
      end
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

    it 'should handle yaml automatically' do
      yaml = "books: \n  book: \n    name: Foo Bar!\n    id: \"1234\"\n"
      @request.options[:format] = :yaml
      @request.send(:parse_response, yaml).should == {'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}}
    end

    it "should include any HTTP headers in the returned response" do
      @request.options[:format] = :html
      response = stub_response "Content"
      response.initialize_http_header("key" => "value")

      @request.perform.headers.should == { "key" => ["value"] }
    end
    
    describe 'with non-200 responses' do

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

    end
  end

  it "should not attempt to parse empty responses" do
    stub_response "", 204

    @request.options[:format] = :xml
    @request.perform.should be_nil
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

      it "should be handled by PUT transparently" do
        @request.http_method = Net::HTTP::Put
        @request.perform.should == {"hash" => {"foo" => "bar"}}
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
end

describe HTTParty::Request, "with POST http method" do
  it "should raise argument error if query is not a hash" do
    lambda {
      HTTParty::Request.new(Net::HTTP::Post, 'http://api.foo.com/v1', :format => :xml, :query => 'astring').perform
    }.should raise_error(ArgumentError)
  end
end
