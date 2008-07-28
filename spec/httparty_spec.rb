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
  
  it 'should be able to get the base_uri' do
    Foo.base_uri.should == 'http://api.foo.com/v1'
  end
  
  it 'should be able to set the base_uri' do
    Foo.base_uri('api.foobar.com')
    Foo.base_uri.should == 'http://api.foobar.com'
  end
  
  it 'should set scheme to https if port 443' do
    FooWithHttps.base_uri.should == 'https://api.foo.com/v1:443'
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
  
  it 'should be able to set basic authentication' do
    Foo.basic_auth 'foobar', 'secret'
    Foo.instance_variable_get("@auth").should == {:username => 'foobar', :password => 'secret'}
  end
  
end