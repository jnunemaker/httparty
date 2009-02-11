require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe HTTParty::Parsers::JSON do
  TESTS = {
    %q({"data": "G\u00fcnter"})                   => {"data" => "Günter"},
    %q({"returnTo":{"\/categories":"\/"}})        => {"returnTo" => {"/categories" => "/"}},
    %q({returnTo:{"\/categories":"\/"}})          => {"returnTo" => {"/categories" => "/"}},
    %q({"return\\"To\\":":{"\/categories":"\/"}}) => {"return\"To\":" => {"/categories" => "/"}},
    %q({"returnTo":{"\/categories":1}})           => {"returnTo" => {"/categories" => 1}},
    %({"returnTo":[1,"a"]})                       => {"returnTo" => [1, "a"]},
    %({"returnTo":[1,"\\"a\\",", "b"]})           => {"returnTo" => [1, "\"a\",", "b"]},
    %({a: "'", "b": "5,000"})                     => {"a" => "'", "b" => "5,000"},
    %({a: "a's, b's and c's", "b": "5,000"})      => {"a" => "a's, b's and c's", "b" => "5,000"},
    %({a: "2007-01-01"})                          => {'a' => Date.new(2007, 1, 1)}, 
    %({a: "2007-01-01 01:12:34 Z"})               => {'a' => Time.utc(2007, 1, 1, 1, 12, 34)}, 
    # no time zone                                
    %({a: "2007-01-01 01:12:34"})                 => {'a' => "2007-01-01 01:12:34"}, 
    %([])    => [],
    %({})    => {},
    %(1)     => 1,
    %("")    => "",
    %("\\"") => "\"",
    %(null)  => nil,
    %(true)  => true,
    %(false) => false,
    %q("http:\/\/test.host\/posts\/1") => "http://test.host/posts/1"
  }
  
  TESTS.each do |json, expected|
    it "should decode json (#{json})" do
      lambda {
        HTTParty::Parsers::JSON.decode(json).should == expected
      }.should_not raise_error
    end
  end
  
  it "should raise error for failed decoding" do
    lambda {
      HTTParty::Parsers::JSON.decode(%({: 1}))
    }.should raise_error(HTTParty::Parsers::JSON::ParseError)
  end
end