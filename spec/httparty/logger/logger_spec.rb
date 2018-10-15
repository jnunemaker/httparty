require 'spec_helper'

RSpec.describe HTTParty::Logger do
  describe ".build" do
    subject { HTTParty::Logger }

    it "defaults level to :info" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil).level).to eq(:info)
    end

    it "defaults format to :apache" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil)).to be_an_instance_of(HTTParty::Logger::ApacheFormatter)
    end

    it "builds :curl style logger" do
      logger_double = double
      expect(subject.build(logger_double, nil, :curl)).to be_an_instance_of(HTTParty::Logger::CurlFormatter)
    end

    it "builds :logstash style logger" do
      logger_double = double
      expect(subject.build(logger_double, nil, :logstash)).to be_an_instance_of(HTTParty::Logger::LogstashFormatter)
    end

    it "builds :custom style logger" do
      CustomFormatter = Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter(:custom, CustomFormatter)

      logger_double = double
      expect(subject.build(logger_double, nil, :custom)).
        to be_an_instance_of(CustomFormatter)
    end
    it "raises error when formatter exists" do
      CustomFormatter2= Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter(:custom2, CustomFormatter2)

      expect{ HTTParty::Logger.add_formatter(:custom2, CustomFormatter2) }.
        to raise_error HTTParty::Error
    end
  end
end
