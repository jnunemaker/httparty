module HTTParty
  class Response
    attr_accessor :body, :code

    def initialize(delegate, body, code)
      @delegate = delegate
      @body = body
      @code = code
    end

    def method_missing(name, *args)
      @delegate.send(name, *args)
    end

    def ==(other)
      @delegate == other
    end
    
    def nil?
      @delegate.nil?
    end

    def pretty_print(q)
      @delegate.pretty_print(q)
    end
  end
end