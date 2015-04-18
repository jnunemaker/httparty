require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

RSpec.describe HTTParty::Logger do
  describe ".build" do
    subject { HTTParty::Logger }

    it "defaults level to :info" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil).level).to eq(:info)
    end

    it "defaults format to :apache" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil)).to be_an_instance_of(HTTParty::Logger::ApacheLogger)
    end

    it "builds :curl style logger" do
      logger_double = double
      expect(subject.build(logger_double, nil, :curl)).to be_an_instance_of(HTTParty::Logger::CurlLogger)
    end
  end
end
