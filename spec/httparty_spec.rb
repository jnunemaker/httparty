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
      Foo.instance_variable_get("@format").should == 'xml'
    end
    
    it "should allow json" do
      Foo.format :json
      Foo.instance_variable_get("@format").should == 'json'
    end
    
    it 'should not allow funky format' do
      lambda do
        Foo.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat)
    end
  end
  
  describe 'http' do
    it "should use ssl for port 443" do
      FooWithHttps.http.use_ssl?.should == true
    end
    
    it 'should not use ssl for port 80' do
      Foo.base_uri('foobar.com')
      Foo.http.use_ssl?.should == false
    end
  end
  
  describe "deriving format from path" do
    it "should work if there is extension and extension is an allowed format" do
      %w[xml json].each do |ext|
        Foo.send(:format_from_path, "/foo/bar.#{ext}").should == ext
      end
    end
    
    it "should NOT work if there is extension but extention is not allow format" do
      Foo.send(:format_from_path, '/foo/bar.php').should == nil
    end
    
    it 'should NOT work if there is no extension' do
      ['', '.'].each do |ext|
        Foo.send(:format_from_path, "/foo/bar#{ext}").should == nil
      end
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
end