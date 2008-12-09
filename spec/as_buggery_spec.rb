require File.join(File.dirname(__FILE__), 'spec_helper')

require 'activesupport'

describe Hash do
  describe "#from_xml" do
    it "should be able to convert xml with datetimes" do
      xml =<<EOL
<?xml version="1.0" encoding="UTF-8"?>
<created-at type="datetime">2008-12-01T20:00:00-05:00</created-at>
EOL
      hsh = Hash.from_xml(xml)
      hsh["created_at"].should == Time.parse("December 01st, 2008 20:00:00")
    end
  end
end