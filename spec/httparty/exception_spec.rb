require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe HTTParty::Error do
  subject { described_class }

  its(:ancestors) { should include(StandardError) }

  describe HTTParty::UnsupportedFormat do
    its(:ancestors) { should include(HTTParty::Error) }
  end
  
  describe HTTParty::UnsupportedURIScheme do
    its(:ancestors) { should include(HTTParty::Error) }
  end

  describe HTTParty::ResponseError do
    its(:ancestors) { should include(HTTParty::Error) }
  end

  describe HTTParty::RedirectionTooDeep do
    its(:ancestors) { should include(HTTParty::ResponseError) }
  end
end
