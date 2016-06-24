require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.describe HTTParty::Error do
  subject { described_class }

  describe '#ancestors' do
    subject { super().ancestors }
    it { is_expected.to include(StandardError) }
  end

  describe HTTParty::UnsupportedFormat do
    describe '#ancestors' do
      subject { super().ancestors }
      it { is_expected.to include(HTTParty::Error) }
    end
  end

  describe HTTParty::UnsupportedURIScheme do
    describe '#ancestors' do
      subject { super().ancestors }
      it { is_expected.to include(HTTParty::Error) }
    end
  end

  describe HTTParty::ResponseError do
    describe '#ancestors' do
      subject { super().ancestors }
      it { is_expected.to include(HTTParty::Error) }
    end
  end

  describe HTTParty::RedirectionTooDeep do
    describe '#ancestors' do
      subject { super().ancestors }
      it { is_expected.to include(HTTParty::ResponseError) }
    end
  end

  describe HTTParty::DuplicateLocationHeader do
    describe '#ancestors' do
      subject { super().ancestors }
      it { is_expected.to include(HTTParty::ResponseError) }
    end
  end
end
