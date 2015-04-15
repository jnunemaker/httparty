require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe HTTParty::Parser do
  describe ".SupportedFormats" do
    it "returns a hash" do
      expect(HTTParty::Parser::SupportedFormats).to be_instance_of(Hash)
    end
  end

  describe ".call" do
    it "generates an HTTParty::Parser instance with the given body and format" do
      expect(HTTParty::Parser).to receive(:new).with('body', :plain).and_return(double(parse: nil))
      HTTParty::Parser.call('body', :plain)
    end

    it "calls #parse on the parser" do
      parser = double('Parser')
      expect(parser).to receive(:parse)
      allow(HTTParty::Parser).to receive_messages(new: parser)
      parser = HTTParty::Parser.call('body', :plain)
    end
  end

  describe ".formats" do
    it "returns the SupportedFormats constant" do
      expect(HTTParty::Parser.formats).to eq(HTTParty::Parser::SupportedFormats)
    end

    it "returns the SupportedFormats constant for subclasses" do
      class MyParser < HTTParty::Parser
        SupportedFormats = {"application/atom+xml" => :atom}
      end
      expect(MyParser.formats).to eq({"application/atom+xml" => :atom})
    end
  end

  describe ".format_from_mimetype" do
    it "returns a symbol representing the format mimetype" do
      expect(HTTParty::Parser.format_from_mimetype("text/plain")).to eq(:plain)
    end

    it "returns nil when the mimetype is not supported" do
      expect(HTTParty::Parser.format_from_mimetype("application/atom+xml")).to be_nil
    end
  end

  describe ".supported_formats" do
    it "returns a unique set of supported formats represented by symbols" do
      expect(HTTParty::Parser.supported_formats).to eq(HTTParty::Parser::SupportedFormats.values.uniq)
    end
  end

  describe ".supports_format?" do
    it "returns true for a supported format" do
      allow(HTTParty::Parser).to receive_messages(supported_formats: [:json])
      expect(HTTParty::Parser.supports_format?(:json)).to be_truthy
    end

    it "returns false for an unsupported format" do
      allow(HTTParty::Parser).to receive_messages(supported_formats: [])
      expect(HTTParty::Parser.supports_format?(:json)).to be_falsey
    end
  end

  describe "#parse" do
    before do
      @parser = HTTParty::Parser.new('body', :json)
    end

    it "attempts to parse supported formats" do
      allow(@parser).to receive_messages(supports_format?: true)
      expect(@parser).to receive(:parse_supported_format)
      @parser.parse
    end

    it "returns the unparsed body when the format is unsupported" do
      allow(@parser).to receive_messages(supports_format?: false)
      expect(@parser.parse).to eq(@parser.body)
    end

    it "returns nil for an empty body" do
      allow(@parser).to receive_messages(body: '')
      expect(@parser.parse).to be_nil
    end

    it "returns nil for a nil body" do
      allow(@parser).to receive_messages(body: nil)
      expect(@parser.parse).to be_nil
    end

    it "returns nil for a 'null' body" do
      allow(@parser).to receive_messages(body: "null")
      expect(@parser.parse).to be_nil
    end

    it "returns nil for a body with spaces only" do
      allow(@parser).to receive_messages(body: "   ")
      expect(@parser.parse).to be_nil
    end
  end

  describe "#supports_format?" do
    it "utilizes the class method to determine if the format is supported" do
      expect(HTTParty::Parser).to receive(:supports_format?).with(:json)
      parser = HTTParty::Parser.new('body', :json)
      parser.send(:supports_format?)
    end
  end

  describe "#parse_supported_format" do
    it "calls the parser for the given format" do
      parser = HTTParty::Parser.new('body', :json)
      expect(parser).to receive(:json)
      parser.send(:parse_supported_format)
    end

    context "when a parsing method does not exist for the given format" do
      it "raises an exception" do
        parser = HTTParty::Parser.new('body', :atom)
        expect do
          parser.send(:parse_supported_format)
        end.to raise_error(NotImplementedError, "HTTParty::Parser has not implemented a parsing method for the :atom format.")
      end

      it "raises a useful exception message for subclasses" do
        atom_parser = Class.new(HTTParty::Parser) do
          def self.name;
            'AtomParser';
          end
        end
        parser = atom_parser.new 'body', :atom
        expect do
          parser.send(:parse_supported_format)
        end.to raise_error(NotImplementedError, "AtomParser has not implemented a parsing method for the :atom format.")
      end
    end
  end

  context "parsers" do
    subject do
      HTTParty::Parser.new('body', nil)
    end

    it "parses xml with MultiXml" do
      expect(MultiXml).to receive(:parse).with('body')
      subject.send(:xml)
    end

    it "parses json with JSON" do
      expect(JSON).to receive(:load).with('body', nil)
      subject.send(:json)
    end

    it "parses html by simply returning the body" do
      expect(subject.send(:html)).to eq('body')
    end

    it "parses plain text by simply returning the body" do
      expect(subject.send(:plain)).to eq('body')
    end

    it "parses csv with CSV" do
      expect(CSV).to receive(:parse).with('body')
      subject.send(:csv)
    end
  end
end
