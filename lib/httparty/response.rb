module HTTParty
  class Response < BlankSlate #:nodoc:
    attr_accessor :body, :code, :headers
    attr_reader :delegate

    def initialize(delegate, body, code, headers={})
      @delegate = delegate
      @body = body
      @code = code
      @headers = headers
    end

    def method_missing(name, *args, &block)
      @delegate.send(name, *args, &block)
    end
  end
end
