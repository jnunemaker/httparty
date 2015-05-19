module HTTParty
  class Response < BasicObject
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
    end

    def parsed_response
      @parsed_response ||= @parsed_block.call
    end

    def class
      Response
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
      define_method("#{underscore(name)}?") do
        klass === response
      end
    end

    # Support old multiple_choice? method from pre 2.0.0 era.
    if ::RUBY_VERSION >= "2.0.0" && ::RUBY_PLATFORM != "java"
      alias_method :multiple_choice?, :multiple_choices?
    end

    def respond_to?(name, include_all = false)
      return true if [:request, :response, :parsed_response, :body, :headers].include?(name)
      parsed_response.respond_to?(name, include_all) || response.respond_to?(name, include_all)
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
  end
end

require 'httparty/response/headers'
