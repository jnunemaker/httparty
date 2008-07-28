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
  
  describe 'base_uri' do
    it 'should allow getting' do
      Foo.base_uri.should == 'http://api.foo.com/v1'
    end
    
    it 'should allow setting' do
      Foo.base_uri('api.foobar.com')
      Foo.base_uri.should == 'http://api.foobar.com'
    end
    
    it 'should set to https if port 443' do
      FooWithHttps.base_uri.should == 'https://api.foo.com/v1:443'
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
  
  describe 'GET' do
    
  end
end