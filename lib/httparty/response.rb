module HTTParty
  class Response
    attr_accessor :body, :code

    def initialize(delegate, body, code)
      @delegate = delegate
      @body = body
      @code = code
    end

    def method_missing(name, *args, &block)
      @delegate.send(name, *args, &block)
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