require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe HTTParty::Response do
  describe "initialization" do
    before do
      @response_object = {'foo' => 'bar'}
      @body = "{foo:'bar'}"
      @code = '200'
      @message = 'OK'
      @response = HTTParty::Response.new(@response_object, @body, @code, @message)
    end
    
    it "should set delegate" do
      @response.delegate.should == @response_object
    end
    
    it "should set body" do
      @response.body.should == @body
    end
    
    it "should set code" do
      @response.code.should.to_s == @code
    end

    it "should set code as a Fixnum" do
      @response.code.should be_an_instance_of(Fixnum)
    end
    
    it "should set body" do
      @response.body.should == @body
    end
  end
  
  it "should be able to set headers during initialization" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200, 'OK', {'foo' => 'bar'})
    response.headers.should == {'foo' => 'bar'}
  end
  
  it "should send missing methods to delegate" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200, 'OK')
    response['foo'].should == 'bar'
  end
  
  it "should be able to iterate delegate if it is array" do
    response = HTTParty::Response.new([{'foo' => 'bar'}, {'foo' => 'baz'}], "[{foo:'bar'}, {foo:'baz'}]", 200, 'OK')
    response.size.should == 2
    lambda {
      response.each { |item| }
    }.should_not raise_error
  end
  
  xit "should allow hashes to be accessed with dot notation" do
    response = HTTParty::Response.new({'foo' => 'bar'}, "{foo:'bar'}", 200, 'OK')
    response.foo.should == 'bar'
  end
  
  xit "should allow nested hashes to be accessed with dot notation" do
    response = HTTParty::Response.new({'foo' => {'bar' => 'baz'}}, "{foo: {bar:'baz'}}", 200, 'OK')
    response.foo.should == {'bar' => 'baz'}
    response.foo.bar.should == 'baz'
  end
end