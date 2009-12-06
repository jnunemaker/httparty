require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

class CustomParser
  def self.parse(body)
    return {:sexy => true}
  end
end

describe HTTParty do
  before(:each) do
    @klass = Class.new
    @klass.instance_eval { include HTTParty }
  end

  describe "AllowedFormats deprecated" do
    before do
      Kernel.stub(:warn)
    end
    it "warns with a deprecation message" do
      Kernel.should_receive(:warn).with("Deprecated: Use HTTParty::Parser::SupportedFormats")
      HTTParty::AllowedFormats
    end

    it "returns HTTPart::Parser::SupportedFormats" do
      HTTParty::AllowedFormats.should == HTTParty::Parser::SupportedFormats
    end
  end

  describe "base uri" do
    before(:each) do
      @klass.base_uri('api.foo.com/v1')
    end

    it "should have reader" do
      @klass.base_uri.should == 'http://api.foo.com/v1'
    end

    it 'should have writer' do
      @klass.base_uri('http://api.foobar.com')
      @klass.base_uri.should == 'http://api.foobar.com'
    end

    it 'should not modify the parameter during assignment' do
      uri = 'http://api.foobar.com'
      @klass.base_uri(uri)
      uri.should == 'http://api.foobar.com'
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

    it 'should not modify the parameter' do
      uri = 'http://api.foobar.com'
      HTTParty.normalize_base_uri(uri)
      uri.should == 'http://api.foobar.com'
    end
  end

  describe "headers" do
    def expect_headers(header={})
      HTTParty::Request.should_receive(:new) \
        .with(anything, anything, hash_including({ :headers => header })) \
        .and_return(mock("mock response", :perform => nil))
    end

    it "should default to empty hash" do
      @klass.headers.should == {}
    end

    it "should be able to be updated" do
      init_headers = {:foo => 'bar', :baz => 'spax'}
      @klass.headers init_headers
      @klass.headers.should == init_headers
    end

    it "uses the class headers when sending a request" do
      expect_headers(:foo => 'bar')
      @klass.headers(:foo => 'bar')
      @klass.get('')
    end

    it "overwrites class headers when passing in headers" do
      expect_headers(:baz => 'spax')
      @klass.headers(:foo => 'bar')
      @klass.get('', :headers => {:baz => 'spax'})
    end

    context "with cookies" do
      it 'utilizes the class-level cookies' do
        expect_headers(:foo => 'bar', 'cookie' => 'type=snickerdoodle')
        @klass.headers(:foo => 'bar')
        @klass.cookies(:type => 'snickerdoodle')
        @klass.get('')
      end

      it 'adds cookies to the headers' do
        expect_headers(:foo => 'bar', 'cookie' => 'type=snickerdoodle')
        @klass.headers(:foo => 'bar')
        @klass.get('', :cookies => {:type => 'snickerdoodle'})
      end

      it 'adds optional cookies to the optional headers' do
        expect_headers(:baz => 'spax', 'cookie' => 'type=snickerdoodle')
        @klass.get('', :cookies => {:type => 'snickerdoodle'}, :headers => {:baz => 'spax'})
      end
    end
  end

  describe "cookies" do
    def expect_cookie_header(s)
      HTTParty::Request.should_receive(:new) \
        .with(anything, anything, hash_including({ :headers => { "cookie" => s } })) \
        .and_return(mock("mock response", :perform => nil))
    end

    it "should not be in the headers by default" do
      HTTParty::Request.stub!(:new).and_return(stub(nil, :perform => nil))
      @klass.get("")
      @klass.headers.keys.should_not include("cookie")
    end

    it "should raise an ArgumentError if passed a non-Hash" do
      lambda do
        @klass.cookies("nonsense")
      end.should raise_error(ArgumentError)
    end

    it "should allow a cookie to be specified with a one-off request" do
      expect_cookie_header "type=snickerdoodle"
      @klass.get("", :cookies => { :type => "snickerdoodle" })
    end

    describe "when a cookie is set at the class level" do
      before(:each) do
        @klass.cookies({ :type => "snickerdoodle" })
      end

      it "should include that cookie in the request" do
        expect_cookie_header "type=snickerdoodle"
        @klass.get("")
      end

      it "should pass the proper cookies when requested multiple times" do
        2.times do
          expect_cookie_header "type=snickerdoodle"
          @klass.get("")
        end
      end

      it "should allow the class defaults to be overridden" do
        expect_cookie_header "type=chocolate_chip"

        @klass.get("", :cookies => { :type => "chocolate_chip" })
      end
    end

    describe "in a class with multiple methods that use different cookies" do
      before(:each) do
        @klass.instance_eval do
          def first_method
            get("first_method", :cookies => { :first_method_cookie => "foo" })
          end

          def second_method
            get("second_method", :cookies => { :second_method_cookie => "foo" })
          end
        end
      end

      it "should not allow cookies used in one method to carry over into other methods" do
        expect_cookie_header "first_method_cookie=foo"
        @klass.first_method

        expect_cookie_header "second_method_cookie=foo"
        @klass.second_method
      end
    end
  end

  describe "default params" do
    it "should default to empty hash" do
      @klass.default_params.should == {}
    end

    it "should be able to be updated" do
      new_defaults = {:foo => 'bar', :baz => 'spax'}
      @klass.default_params new_defaults
      @klass.default_params.should == new_defaults
    end
  end

  describe "basic http authentication" do
    it "should work" do
      @klass.basic_auth 'foobar', 'secret'
      @klass.default_options[:basic_auth].should == {:username => 'foobar', :password => 'secret'}
    end
  end

  describe "parser" do
    let(:parser) do
      Proc.new{ |data, format| CustomParser.parse(data) }
    end

    it "should set parser options" do
      @klass.parser parser
      @klass.default_options[:parser].should == parser
    end

    it "should be able parse response with custom parser" do
      @klass.parser parser
      FakeWeb.register_uri(:get, 'http://twitter.com/statuses/public_timeline.xml', :body => 'tweets')
      custom_parsed_response = @klass.get('http://twitter.com/statuses/public_timeline.xml')
      custom_parsed_response[:sexy].should == true
    end

    it "raises UnsupportedFormat when the parser cannot handle the format" do
      @klass.format :json
      class MyParser < HTTParty::Parser
        SupportedFormats = {}
      end
      expect do
        @klass.parser MyParser
      end.to raise_error(HTTParty::UnsupportedFormat)
    end

    it 'does not validate format whe custom parser is a proc' do
      expect do
        @klass.format :json
        @klass.parser lambda {|body, format|}
      end.to_not raise_error(HTTParty::UnsupportedFormat)
    end
  end

  describe "format" do
    it "should allow xml" do
      @klass.format :xml
      @klass.default_options[:format].should == :xml
    end

    it "should allow json" do
      @klass.format :json
      @klass.default_options[:format].should == :json
    end

    it "should allow yaml" do
      @klass.format :yaml
      @klass.default_options[:format].should == :yaml
    end

    it "should allow plain" do
      @klass.format :plain
      @klass.default_options[:format].should == :plain
    end

    it 'should not allow funky format' do
      lambda do
        @klass.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat)
    end

    it 'should only print each format once with an exception' do
      lambda do
        @klass.format :foobar
      end.should raise_error(HTTParty::UnsupportedFormat, "':foobar' Must be one of: html, json, plain, xml, yaml")
    end

    it 'sets the default parser' do
      @klass.default_options[:parser].should be_nil
      @klass.format :json
      @klass.default_options[:parser].should == HTTParty::Parser
    end

    it 'does not reset parser to the default parser' do
      my_parser = lambda {}
      @klass.parser my_parser
      @klass.format :json
      @klass.parser.should == my_parser
    end
  end

  describe "with explicit override of automatic redirect handling" do

    it "should fail with redirected GET" do
      lambda do
        @klass.get('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected POST" do
      lambda do
        @klass.post('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected DELETE" do
      lambda do
        @klass.delete('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected PUT" do
      lambda do
        @klass.put('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected HEAD" do
      lambda do
        @klass.head('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end

    it "should fail with redirected OPTIONS" do
      lambda do
        @klass.options('/foo', :no_follow => true)
      end.should raise_error(HTTParty::RedirectionTooDeep)
    end
  end

  describe "with multiple class definitions" do
    before(:each) do
      @klass.instance_eval do
        base_uri "http://first.com"
        default_params :one => 1
      end

      @additional_klass = Class.new
      @additional_klass.instance_eval do
        include HTTParty
        base_uri "http://second.com"
        default_params :two => 2
      end
    end

    it "should not run over each others options" do
      @klass.default_options.should == { :base_uri => 'http://first.com', :default_params => { :one => 1 } }
      @additional_klass.default_options.should == { :base_uri => 'http://second.com', :default_params => { :two => 2 } }
    end
  end

  describe "two child classes inheriting from one parent" do
    before(:each) do
      @parent = Class.new do
        include HTTParty
      end

      @child1 = Class.new(@parent)
      @child2 = Class.new(@parent)
    end

    it "does not modify each others inherited attributes" do
      @child1.default_params :joe => "alive"
      @child2.default_params :joe => "dead"

      @child1.default_options.should == { :default_params => {:joe => "alive"} }
      @child2.default_options.should == { :default_params => {:joe => "dead"} }

      @parent.default_options.should == { }
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

    it "should not get undefined method add_node for nil class for the following xml" do
      stub_http_response_with('undefined_method_add_node_for_nil.xml')
      result = HTTParty.get('http://foobar.com')
      result.should == {"Entities"=>{"href"=>"https://s3-sandbox.parature.com/api/v1/5578/5633/Account", "results"=>"0", "total"=>"0", "page_size"=>"25", "page"=>"1"}}
    end

    it "should parse empty response fine" do
      stub_http_response_with('empty.xml')
      result = HTTParty.get('http://foobar.com')
      result.should be_nil
    end

    it "should accept http URIs" do
      stub_http_response_with('google.html')
      lambda do
        HTTParty.get('http://google.com')
      end.should_not raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should accept https URIs" do
      stub_http_response_with('google.html')
      lambda do
        HTTParty.get('https://google.com')
      end.should_not raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should raise an ArgumentError on URIs that are not http or https" do
      lambda do
        HTTParty.get("file:///there_is_no_party_on/my/filesystem")
      end.should raise_error(HTTParty::UnsupportedURIScheme)
    end

    it "should raise an InvalidURIError on URIs that can't be parsed at all" do
      lambda do
        HTTParty.get("It's the one that says 'Bad URI'")
      end.should raise_error(URI::InvalidURIError)
    end
  end
end
