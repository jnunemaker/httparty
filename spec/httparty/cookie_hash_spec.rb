require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

RSpec.describe HTTParty::CookieHash do
  before(:each) do
    @cookie_hash = HTTParty::CookieHash.new
  end

  describe "#add_cookies" do
    describe "with a hash" do
      it "should add new key/value pairs to the hash" do
        @cookie_hash.add_cookies(foo: "bar")
        @cookie_hash.add_cookies(rofl: "copter")
        expect(@cookie_hash.length).to eql(2)
      end

      it "should overwrite any existing key" do
        @cookie_hash.add_cookies(foo: "bar")
        @cookie_hash.add_cookies(foo: "copter")
        expect(@cookie_hash.length).to eql(1)
        expect(@cookie_hash[:foo]).to eql("copter")
      end
    end

    describe "with a string" do
      it "should add new key/value pairs to the hash" do
        @cookie_hash.add_cookies("first=one; second=two; third")
        expect(@cookie_hash[:first]).to eq('one')
        expect(@cookie_hash[:second]).to eq('two')
        expect(@cookie_hash[:third]).to eq(nil)
      end

      it "should overwrite any existing key" do
        @cookie_hash[:foo] = 'bar'
        @cookie_hash.add_cookies("foo=tar")
        expect(@cookie_hash.length).to eql(1)
        expect(@cookie_hash[:foo]).to eql("tar")
      end

      it "should handle '=' within cookie value" do
        @cookie_hash.add_cookies("first=one=1; second=two=2==")
        expect(@cookie_hash.keys).to include(:first, :second)
        expect(@cookie_hash[:first]).to eq('one=1')
        expect(@cookie_hash[:second]).to eq('two=2==')
      end
    end

    describe 'with other class' do
      it "should error" do
        expect {
          @cookie_hash.add_cookies([])
        }.to raise_error(RuntimeError)
      end
    end
  end

  # The regexen are required because Hashes aren't ordered, so a test against
  # a hardcoded string was randomly failing.
  describe "#to_cookie_string" do
    before(:each) do
      @cookie_hash.add_cookies(foo: "bar")
      @cookie_hash.add_cookies(rofl: "copter")
      @s = @cookie_hash.to_cookie_string
    end

    it "should format the key/value pairs, delimited by semi-colons" do
      expect(@s).to match(/foo=bar/)
      expect(@s).to match(/rofl=copter/)
      expect(@s).to match(/^\w+=\w+; \w+=\w+$/)
    end

    it "should not include client side only cookies" do
      @cookie_hash.add_cookies(path: "/")
      @s = @cookie_hash.to_cookie_string
      expect(@s).not_to match(/path=\//)
    end

    it "should not include client side only cookies even when attributes use camal case" do
      @cookie_hash.add_cookies(Path: "/")
      @s = @cookie_hash.to_cookie_string
      expect(@s).not_to match(/Path=\//)
    end

    it "should not mutate the hash" do
      original_hash = {
        "session" => "91e25e8b-6e32-418d-c72f-2d18adf041cd",
        "Max-Age" => "15552000",
        "cart" => "91e25e8b-6e32-418d-c72f-2d18adf041cd",
        "httponly" => nil,
        "Path" => "/",
        "secure" => nil,
      }

      cookie_hash = HTTParty::CookieHash[original_hash]

      cookie_hash.to_cookie_string

      expect(cookie_hash).to eq(original_hash)
    end
  end
end
