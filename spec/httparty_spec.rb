require File.join(File.dirname(__FILE__), 'spec_helper')

class Foo
  include HTTParty
  base_uri 'api.foo.com/v1'
end

class FooWithHttps
  include HTTParty
  base_uri 'api.foo.com/v1:443'
end

describe HTTParty do
  
  describe "base uri" do
    it "should be gettable" do
      Foo.base_uri.should == 'http://api.foo.com/v1'
    end
    
    it 'should be setable' do
      Foo.base_uri('http://api.foobar.com')
      Foo.base_uri.should == 'http://api.foobar.com'
    end
    
    it "should add http if not present for non ssl requests" do
      Foo.base_uri('api.foobar.com')
      Foo.base_uri.should == 'http://api.foobar.com'
    end
    
    it "should add https if not present for ssl requests" do
      FooWithHttps.base_uri.should == 'https://api.foo.com/v1:443'
    end
  end
  
  describe "headers" do
    it "should default to empty hash" do
      Foo.headers.should == {}
    end
    
    it "should be able to be updated" do
      init_headers = {:foo => 'bar', :baz => 'spax'}
      Foo.headers init_headers
      Foo.headers.should == init_headers
    end
  end
  
  describe "default params" do
    it "should default to empty hash" do
      Foo.default_params.should == {}
    end
    
    it "should be able to be updated" do
      new_defaults = {:foo => 'bar', :baz => 'spax'}
      Foo.default_params new_defaults
      Foo.default_params.should == new_defaults
    end
  end
  
  describe "basic http authentication" do
    it "should work" do
      Foo.basic_auth 'foobar', 'secret'
      Foo.instance_variable_get("@auth").should == {:username => 'foobar', :password => 'secret'}
    end
  end
  
  describe "format" do
    it "should allow xml" do
      Foo.format :xml
      Foo.instance_variable_get("@format").should == :xml
    end
    
    it "should allow json" do
      Foo.format :json
      Foo.instance_variable_get("@format").should == :json
    end
    
    it 'should not allow funky format' do
      lambda do
        Foo.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat)
    end
  end
  
  describe 'http' do
    it "should use ssl for port 443" do
      FooWithHttps.send(:http, URI.parse('https://api.foo.com/v1:443')).use_ssl?.should == true
    end
    
    it 'should not use ssl for port 80' do
      Foo.send(:http, URI.parse('http://foobar.com')).use_ssl?.should == false
    end
  end
  
  describe 'parsing responses' do
    it 'should handle xml automatically' do
      xml = %q[<books><book><id>1234</id><name>Foo Bar!</name></book></books>]
      Foo.format :xml
      Foo.send(:parse_response, xml).should == {'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}}
    end
    
    it 'should handle json automatically' do
      json = %q[{"books": {"book": {"name": "Foo Bar!", "id": "1234"}}}]
      Foo.format :json
      Foo.send(:parse_response, json).should == {'books' => {'book' => {'id' => '1234', 'name' => 'Foo Bar!'}}}
    end
  end
  
  describe "sending requests" do
    it "should not work with request method other than get, post, put, delete" do
      lambda do
        Foo.send(:send_request, 'foo', '/foo')
      end.should raise_error(ArgumentError)
    end
    
    it 'should require that :headers is a hash if present' do
      lambda do
        Foo.send(:send_request, 'get', '/foo', :headers => 'string')
      end.should raise_error(ArgumentError)
    end
    
    it 'should require that :basic_auth is a hash if present' do
      lambda do
        Foo.send(:send_request, 'get', '/foo', :basic_auth => 'string')
      end.should raise_error(ArgumentError)
    end

    it "should not attempt to parse empty responses" do
      http = Net::HTTP.new('localhost', 80)
      Foo.stub!(:http).and_return(http)
      response = Net::HTTPNoContent.new("1.1", 204, "No content for you")
      response.stub!(:body).and_return(nil)
      http.stub!(:request).and_return(response)

      Foo.headers.clear # clear out bogus settings from other specs
      Foo.format :xml
      Foo.send(:send_request, 'get', '/bar').should be_nil

      response.stub!(:body).and_return("")
      Foo.send(:send_request, 'get', 'bar').should be_nil
    end

    describe "that respond with redirects" do
      def setup_http
        @http = Net::HTTP.new('localhost', 80)
        Foo.stub!(:http).and_return(@http)
        @redirect = Net::HTTPFound.new("1.1", 302, "")
        @redirect.stub!(:[]).with('location').and_return('/foo')
        @ok = Net::HTTPOK.new("1.1", 200, "Content for you")
        @ok.stub!(:body).and_return({"foo" => "bar"}.to_xml)
        @http.should_receive(:request).and_return(@redirect, @ok)
        Foo.headers.clear
        Foo.format :xml
      end

      it "should handle redirects for GET transparently" do
        setup_http
        Foo.get('/foo/').should == {"hash" => {"foo" => "bar"}}
      end

      it "should handle redirects for POST transparently" do
        setup_http
        Foo.post('/foo/', {:foo => :bar}).should == {"hash" => {"foo" => "bar"}}
      end

      it "should handle redirects for DELETE transparently" do
        setup_http
        Foo.delete('/foo/').should == {"hash" => {"foo" => "bar"}}
      end

      it "should handle redirects for PUT transparently" do
        setup_http
        Foo.put('/foo/').should == {"hash" => {"foo" => "bar"}}
      end

      it "should prevent infinite loops" do
        http = Net::HTTP.new('localhost', 80)
        Foo.stub!(:http).and_return(http)
        redirect = Net::HTTPFound.new("1.1", "302", "Look, over there!")
        redirect.stub!(:[]).with('location').and_return('/foo')
        http.stub!(:request).and_return(redirect)

        lambda do
          Foo.send(:send_request, 'get', '/foo')
        end.should raise_error(HTTParty::RedirectionTooDeep)
      end

      describe "with explicit override of automatic redirect handling" do

        it "should fail with redirected GET" do
          lambda do
            Foo.get('/foo', :no_follow => true)
          end.should raise_error(HTTParty::RedirectionTooDeep)
        end

        it "should fail with redirected POST" do
          lambda do
            Foo.post('/foo', :no_follow => true)
          end.should raise_error(HTTParty::RedirectionTooDeep)
        end

        it "should fail with redirected DELETE" do
          lambda do
            Foo.delete('/foo', :no_follow => true)
          end
        end

        it "should fail with redirected PUT" do
          lambda do
            Foo.put('/foo', :no_follow => true)
          end
        end
      end
    end
  end
end