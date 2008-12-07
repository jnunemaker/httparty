require File.join(File.dirname(__FILE__), 'spec_helper')

class Foo
  include HTTParty
  base_uri 'api.foo.com/v1'
end

class GRest
  include HTTParty
  base_uri "grest.com"
  default_params :one => 'two'
end

class HRest
  include HTTParty
  base_uri "hrest.com"
  default_params :two => 'three'
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
  end
  
  describe "#normalize_base_uri" do
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
  
  describe "with multiple class definitions" do
    it "should not run over each others options" do
      HRest.default_options.should == {:base_uri => 'http://hrest.com', :default_params => {:two => 'three'}}
      GRest.default_options.should == {:base_uri => 'http://grest.com', :default_params => {:one => 'two'}}
    end
  end
  
  describe "#get" do
    it "should be able to get html" do
      stub_http_response_with('google.html')
      HTTParty.get('http://www.google.com').should == file_fixture('google.html')
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
  end
end
