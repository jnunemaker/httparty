require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe HTTParty::Request do
  before do
    @request = HTTParty::Request.new(Net::HTTP::Get, 'http://api.foo.com/v1', :format => :xml)
  end

  describe 'http' do
    it "should use ssl for port 443" do
      @request.send(:http, URI.parse('https://api.foo.com/v1:443')).use_ssl?.should == true
    end
    
    it 'should not use ssl for port 80' do
      @request.send(:http, URI.parse('http://foobar.com')).use_ssl?.should == false
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
  end

  it "should not attempt to parse empty responses" do
    http = Net::HTTP.new('localhost', 80)
    @request.stub!(:http).and_return(http)
    response = Net::HTTPNoContent.new("1.1", 204, "No content for you")
    response.stub!(:body).and_return(nil)
    http.stub!(:request).and_return(response)

    @request.options[:format] = :xml
    @request.perform.should be_nil

    response.stub!(:body).and_return("")
    @request.perform.should be_nil
  end

  describe "that respond with redirects" do
    def setup_redirect
      @http = Net::HTTP.new('localhost', 80)
      @request.stub!(:http).and_return(@http)
      @request.stub!(:uri).and_return(URI.parse("http://foo.com/foobar"))
      @redirect = Net::HTTPFound.new("1.1", 302, "")
      @redirect['location'] = '/foo'
    end

    def setup_ok_response
      @ok = Net::HTTPOK.new("1.1", 200, "Content for you")
      @ok.stub!(:body).and_return({"foo" => "bar"}.to_xml)
      @http.should_receive(:request).and_return(@redirect, @ok)
      @request.options[:format] = :xml
    end

    def setup_redirect_response
      @http.stub!(:request).and_return(@redirect)
    end

    def setup_successful_redirect
      setup_redirect
      setup_ok_response
    end

    def setup_infinite_redirect
      setup_redirect
      setup_redirect_response
    end

    it "should handle redirects for GET transparently" do
      setup_successful_redirect
      @request.perform.should == {"hash" => {"foo" => "bar"}}
    end

    it "should handle redirects for POST transparently" do
      setup_successful_redirect
      @request.http_method = Net::HTTP::Post
      @request.perform.should == {"hash" => {"foo" => "bar"}}
    end

    it "should handle redirects for DELETE transparently" do
      setup_successful_redirect
      @request.http_method = Net::HTTP::Delete
      @request.perform.should == {"hash" => {"foo" => "bar"}}
    end

    it "should handle redirects for PUT transparently" do
      setup_successful_redirect
      @request.http_method = Net::HTTP::Put
      @request.perform.should == {"hash" => {"foo" => "bar"}}
    end

    it "should prevent infinite loops" do
      setup_infinite_redirect

      lambda do
        @request.perform
      end.should raise_error(HTTParty::RedirectionTooDeep)
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