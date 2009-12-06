module HTTParty
  class Parser
    SupportedFormats = {
      'text/xml'               => :xml,
      'application/xml'        => :xml,
      'application/json'       => :json,
      'text/json'              => :json,
      'application/javascript' => :json,
      'text/javascript'        => :json,
      'text/html'              => :html,
      'application/x-yaml'     => :yaml,
      'text/yaml'              => :yaml,
      'text/plain'             => :plain
    }

    attr_reader :body, :format

    def self.call(body, format)
      new(body, format).parse
    end

    def self.formats
      const_get(:SupportedFormats)
    end

    def self.format_from_mimetype(mimetype)
      formats[formats.keys.detect {|k| mimetype.include?(k)}]
    end

    def self.supported_formats
      formats.values.uniq
    end

    def self.supports_format?(format)
      supported_formats.include?(format)
    end

    def initialize(body, format)
      @body = body
      @format = format
    end
    private_class_method :new

    def parse
      return nil if body.nil? || body.empty?
      if supports_format?
        parse_supported_format
      else
        body
      end
    end

    protected

    def xml
      Crack::XML.parse(body)
    end

    def json
      Crack::JSON.parse(body)
    end

    def yaml
      YAML.load(body)
    end

    def html
      body
    end

    def plain
      body
    end

    def supports_format?
      self.class.supports_format?(format)
    end

    def parse_supported_format
      send(format)
      rescue NoMethodError
        raise NotImplementedError, "#{self.class.name} has not implemented a parsing method for the #{format.inspect} format."
    end
  end
end
