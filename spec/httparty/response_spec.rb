require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::Response do
  before do
    @last_modified = Date.new(2010, 1, 15).to_s
    @content_length = '1024'
    @request_object = HTTParty::Request.new Net::HTTP::Get, '/'
    @response_object = Net::HTTPOK.new('1.1', 200, 'OK')
    @response_object.stub(:body => "{foo:'bar'}")
    @response_object['last-modified'] = @last_modified
    @response_object['content-length'] = @content_length
    @parsed_response = {"foo" => "bar"}
    @response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
  end

  describe ".underscore" do
    it "works with one capitalized word" do
      HTTParty::Response.underscore("Accepted").should == "accepted"
    end

    it "works with titlecase" do
      HTTParty::Response.underscore("BadGateway").should == "bad_gateway"
    end

    it "works with all caps" do
      HTTParty::Response.underscore("OK").should == "ok"
    end
  end

  describe "initialization" do
    it "should set the Net::HTTP Response" do
      @response.response.should == @response_object
    end

    it "should set body" do
      @response.body.should == @response_object.body
    end

    it "should set code" do
      @response.code.should.to_s == @response_object.code
    end

    it "should set code as a Fixnum" do
      @response.code.should be_an_instance_of(Fixnum)
    end
  end

  it "returns response headers" do
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    response.headers.should == {'last-modified' => [@last_modified], 'content-length' => [@content_length]}
  end

  it "should send missing methods to delegate" do
    response = HTTParty::Response.new(@request_object, @response_object, {'foo' => 'bar'})
    response['foo'].should == 'bar'
  end
  
  it "should respond_to? methods it supports" do
    response = HTTParty::Response.new(@request_object, @response_object, {'foo' => 'bar'})
    response.respond_to?(:parsed_response).should be_true
  end

  it "should be able to iterate if it is array" do
    response = HTTParty::Response.new(@request_object, @response_object, [{'foo' => 'bar'}, {'foo' => 'baz'}])
    response.size.should == 2
    expect {
      response.each { |item| }
    }.to_not raise_error
  end

  it "allows headers to be accessed by mixed-case names in hash notation" do
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    response.headers['Content-LENGTH'].should == @content_length
  end

  it "returns a comma-delimited value when multiple values exist" do
    @response_object.add_field 'set-cookie', 'csrf_id=12345; path=/'
    @response_object.add_field 'set-cookie', '_github_ses=A123CdE; path=/'
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    response.headers['set-cookie'].should == "csrf_id=12345; path=/, _github_ses=A123CdE; path=/"
  end

  # Backwards-compatibility - previously, #headers returned a Hash
  it "responds to hash methods" do
    response = HTTParty::Response.new(@request_object, @response_object, @parsed_response)
    hash_methods = {}.methods - response.headers.methods
    hash_methods.each do |method_name|
      response.headers.respond_to?(method_name).should be_true
    end
  end

  xit "should allow hashes to be accessed with dot notation" do
    response = HTTParty::Response.new(@request_object, {'foo' => 'bar'}, "{foo:'bar'}", 200, 'OK')
    response.foo.should == 'bar'
  end

  xit "should allow nested hashes to be accessed with dot notation" do
    response = HTTParty::Response.new(@request_object, {'foo' => {'bar' => 'baz'}}, "{foo: {bar:'baz'}}", 200, 'OK')
    response.foo.should == {'bar' => 'baz'}
    response.foo.bar.should == 'baz'
  end

  describe "semantic methods for response codes" do
    def response_mock(klass)
      r = klass.new('', '', '')
      r.stub(:body)
      r
    end

    context "major codes" do
      it "is information" do
        net_response = response_mock(Net::HTTPInformation)
        response = HTTParty::Response.new(@request_object, net_response, '')
        response.information?.should be_true
      end

      it "is success" do
        net_response = response_mock(Net::HTTPSuccess)
        response = HTTParty::Response.new(@request_object, net_response, '')
        response.success?.should be_true
      end

      it "is redirection" do
        net_response = response_mock(Net::HTTPRedirection)
        response = HTTParty::Response.new(@request_object, net_response, '')
        response.redirection?.should be_true
      end

      it "is client error" do
        net_response = response_mock(Net::HTTPClientError)
        response = HTTParty::Response.new(@request_object, net_response, '')
        response.client_error?.should be_true
      end

      it "is server error" do
        net_response = response_mock(Net::HTTPServerError)
        response = HTTParty::Response.new(@request_object, net_response, '')
        response.server_error?.should be_true
      end
    end

    context "for specific codes" do
      SPECIFIC_CODES = {
        :accepted?                        => Net::HTTPAccepted,
        :bad_gateway?                     => Net::HTTPBadGateway,
        :bad_request?                     => Net::HTTPBadRequest,
        :conflict?                        => Net::HTTPConflict,
        :continue?                        => Net::HTTPContinue,
        :created?                         => Net::HTTPCreated,
        :expectation_failed?              => Net::HTTPExpectationFailed,
        :forbidden?                       => Net::HTTPForbidden,
        :found?                           => Net::HTTPFound,
        :gateway_time_out?                => Net::HTTPGatewayTimeOut,
        :gone?                            => Net::HTTPGone,
        :internal_server_error?           => Net::HTTPInternalServerError,
        :length_required?                 => Net::HTTPLengthRequired,
        :method_not_allowed?              => Net::HTTPMethodNotAllowed,
        :moved_permanently?               => Net::HTTPMovedPermanently,
        :multiple_choice?                 => Net::HTTPMultipleChoice,
        :no_content?                      => Net::HTTPNoContent,
        :non_authoritative_information?   => Net::HTTPNonAuthoritativeInformation,
        :not_acceptable?                  => Net::HTTPNotAcceptable,
        :not_found?                       => Net::HTTPNotFound,
        :not_implemented?                 => Net::HTTPNotImplemented,
        :not_modified?                    => Net::HTTPNotModified,
        :ok?                              => Net::HTTPOK,
        :partial_content?                 => Net::HTTPPartialContent,
        :payment_required?                => Net::HTTPPaymentRequired,
        :precondition_failed?             => Net::HTTPPreconditionFailed,
        :proxy_authentication_required?   => Net::HTTPProxyAuthenticationRequired,
        :request_entity_too_large?        => Net::HTTPRequestEntityTooLarge,
        :request_time_out?                => Net::HTTPRequestTimeOut,
        :request_uri_too_long?            => Net::HTTPRequestURITooLong,
        :requested_range_not_satisfiable? => Net::HTTPRequestedRangeNotSatisfiable,
        :reset_content?                   => Net::HTTPResetContent,
        :see_other?                       => Net::HTTPSeeOther,
        :service_unavailable?             => Net::HTTPServiceUnavailable,
        :switch_protocol?                 => Net::HTTPSwitchProtocol,
        :temporary_redirect?              => Net::HTTPTemporaryRedirect,
        :unauthorized?                    => Net::HTTPUnauthorized,
        :unsupported_media_type?          => Net::HTTPUnsupportedMediaType,
        :use_proxy?                       => Net::HTTPUseProxy,
        :version_not_supported?           => Net::HTTPVersionNotSupported
      }.each do |method, klass|
        it "responds to #{method}" do
          net_response = response_mock(klass)
          response = HTTParty::Response.new(@request_object, net_response, '')
          response.__send__(method).should be_true
        end
      end
    end
  end
end
