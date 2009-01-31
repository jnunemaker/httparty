require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe HTTParty::Response do
  describe "initialization" do
    before do
      @response_object = {'foo' => 'bar'}
      @body = "{foo:'bar'}"
      @code = 200
      @response = HTTParty::Response.new(@response_object, @body, @code)
    end
    
    it "should set delegate" do
      @response.delegate.should == @response_object
    end
    
    it "should set body" do
      @response.body.should == @body
    end
    
    it "should set code" do
      @response.code.should == @code
    end
  end
  
  it "should be able to set headers during initialization" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200, {'foo' => 'bar'})
    response.headers.should == {'foo' => 'bar'}
  end
  
  it "should send missing methods to delegate" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200)
    response['foo'].should == 'bar'
  end
  
  it "should be able to iterate delegate if it is array" do
    response = HTTParty::Response.new([{'foo' => 'bar'}, {'foo' => 'baz'}], "[{foo:'bar'}, {foo:'baz'}]", 200)
    response.size.should == 2
    lambda {
      response.each { |item| }
    }.should_not raise_error
  end
  
  xit "should allow hashes to be accessed with dot notation" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200)
    response.foo.should == 'bar'
  end
  
  xit "should allow nested hashes to be accessed with dot notation" do
    response = HTTParty::Response.new({'foo' => {'bar' => 'baz'}}, "{foo: {bar:'baz'}}", 200)
    response.foo.should == {'bar' => 'baz'}
    response.foo.bar.should == 'baz'
  end
end