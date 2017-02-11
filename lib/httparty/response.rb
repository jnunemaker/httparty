module HTTParty
  class Response < Object
    def self.underscore(string)
      string.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z])([A-Z])/, '\1_\2').downcase
    end

    attr_reader :request, :response, :body, :headers

    def initialize(request, response, parsed_block, options = {})
      @request      = request
      @response     = response
      @body         = options[:body] || response.body
      @parsed_block = parsed_block
      @headers      = Headers.new(response.to_hash)

      if request.options[:logger]
        logger = ::HTTParty::Logger.build(request.options[:logger], request.options[:log_level], request.options[:log_format])
        logger.format(request, self)
      end

      throw_exception
    end

    def parsed_response
      @parsed_response ||= @parsed_block.call
    end

    def code
      response.code.to_i
    end

    def tap
      yield self
      self
    end

    def inspect
      inspect_id = ::Kernel::format "%x", (object_id * 2)
      %(#<#{self.class}:0x#{inspect_id} parsed_response=#{parsed_response.inspect}, @response=#{response.inspect}, @headers=#{headers.inspect}>)
    end

    CODES_TO_OBJ = ::Net::HTTPResponse::CODE_CLASS_TO_OBJ.merge ::Net::HTTPResponse::CODE_TO_OBJ

    CODES_TO_OBJ.each do |response_code, klass|
      name = klass.name.sub("Net::HTTP", '')
      name = "#{underscore(name)}?".to_sym

      define_method(name) do
        klass === response
      end
    end

    # Support old multiple_choice? method from pre 2.0.0 era.
    if ::RUBY_VERSION >= "2.0.0" && ::RUBY_PLATFORM != "java"
      alias_method :multiple_choice?, :multiple_choices?
    end

    def nil?
      response.nil? || response.body.nil? || response.body.empty?
    end

    def to_s      
      if !response.nil? && !response.body.nil? && response.body.respond_to?(:to_s)
        response.body.to_s
      else 
        inspect
      end
    end

    def display(port=$>)
      if !parsed_response.nil? && parsed_response.respond_to?(:display)
        parsed_response.display(port)
      elsif !response.nil? && !response.body.nil? && response.body.respond_to?(:display)
        response.body.display(port)
      else 
        port.write(inspect)
      end
    end

    def respond_to_missing?(name, *args)
      return true if super
      parsed_response.respond_to?(name) || response.respond_to?(name)
    end
    
    protected

    def method_missing(name, *args, &block)
      if parsed_response.respond_to?(name)
        parsed_response.send(name, *args, &block)
      elsif response.respond_to?(name)
        response.send(name, *args, &block)
      else
        super
      end
    end

    def throw_exception
      if @request.options[:raise_on] && @request.options[:raise_on].include?(code)
        ::Kernel.raise ::HTTParty::ResponseError.new(@response), "Code #{code} - #{body}"
      end
    end
  end
end

require 'httparty/response/headers'
