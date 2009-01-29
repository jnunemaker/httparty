module HTTParty
  class Response < BlankSlate
    attr_accessor :body, :code

    def initialize(delegate, body, code)
      @delegate = delegate
      @body = body
      @code = code
    end

    def method_missing(name, *args, &block)
      @delegate.send(name, *args, &block)
    end
  end
end
