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
    before do
      Foo.base_uri('api.foo.com/v1')
    end

    it "should have reader" do
      Foo.base_uri.should == 'http://api.foo.com/v1'
    end
    
    it 'should have writer' do
      Foo.base_uri('http://api.foobar.com')
      Foo.base_uri.should == 'http://api.foobar.com'
    end
    
    it "should add http if not present for non ssl requests" do
      Foo.base_uri('api.foobar.com')
      Foo.base_uri.should == 'http://api.foobar.com'
    end
    
    it "should add https if not present for ssl requests" do
      Foo.base_uri('api.foo.com/v1:443')
      Foo.base_uri.should == 'https://api.foo.com/v1:443'
    end
    
    it "should not remove https for ssl requests" do
      Foo.base_uri('https://api.foo.com/v1:443')
      Foo.base_uri.should == 'https://api.foo.com/v1:443'
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
      Foo.default_options[:basic_auth].should == {:username => 'foobar', :password => 'secret'}
    end
  end
  
  describe "format" do
    it "should allow xml" do
      Foo.format :xml
      Foo.default_options[:format].should == :xml
    end
    
    it "should allow json" do
      Foo.format :json
      Foo.default_options[:format].should == :json
    end
    
    it 'should not allow funky format' do
      lambda do
        Foo.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat)
    end
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
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected PUT" do
      lambda do
        Foo.put('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end
  end
end
