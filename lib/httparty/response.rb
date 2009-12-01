module HTTParty
  class Response < HTTParty::BasicObject #:nodoc:
    attr_accessor :body, :code, :message, :headers
    attr_reader :delegate

    def initialize(delegate, body, code, message, headers={})
      @delegate = delegate
      @body = body
      @code = code.to_i
      @message = message
      @headers = headers
    end

    def method_missing(name, *args, &block)
      @delegate.send(name, *args, &block)
    end
  end
end
