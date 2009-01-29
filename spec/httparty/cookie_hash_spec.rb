require File.join(File.dirname(__FILE__), '../spec_helper')

describe HTTParty::CookieHash do
  before(:each) do
    @cookie_hash = HTTParty::CookieHash.new
  end

  describe "#add_cookies" do
    it "should add new key/value pairs to the hash" do
      @cookie_hash.add_cookies(:foo => "bar")
      @cookie_hash.add_cookies(:rofl => "copter")
      @cookie_hash.length.should eql(2)
    end

    it "should overwrite any existing key" do
      @cookie_hash.add_cookies(:foo => "bar")
      @cookie_hash.add_cookies(:foo => "copter")
      @cookie_hash.length.should eql(1)
      @cookie_hash[:foo].should eql("copter")
    end
  end

  # The regexen are required because Hashes aren't ordered, so a test against
  # a hardcoded string was randomly failing.
  describe "#to_cookie_string" do
    before(:each) do
      @cookie_hash.add_cookies(:foo => "bar")
      @cookie_hash.add_cookies(:rofl => "copter")
      @s = @cookie_hash.to_cookie_string
    end

    it "should format the key/value pairs, delimited by semi-colons" do
      @s.should match(/foo=bar/)
      @s.should match(/rofl=copter/)
      @s.should match(/^\w+=\w+; \w+=\w+$/)
    end
  end
end
