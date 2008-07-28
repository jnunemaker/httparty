require File.join(File.dirname(__FILE__), 'spec_helper')

describe HTTParty::CoreExt::HashConversions do
  it "should convert hash to struct" do
    {'foo' => 'bar'}.to_struct.should == OpenStruct.new(:foo => 'bar')
  end
  
  it 'should convert nested hash to struct' do
    {'foo' => {'bar' => 'baz'}}.to_struct.should == OpenStruct.new(:foo => OpenStruct.new(:bar => 'baz'))
  end
end