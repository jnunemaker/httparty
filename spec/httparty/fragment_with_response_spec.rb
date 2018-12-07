require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

RSpec.describe HTTParty::FragmentWithResponse do
  it "access to fragment" do
    fragment = HTTParty::FragmentWithResponse.new("chunk", nil)
    expect(fragment).to eq("chunk")
  end
  it "has access to delegators" do
    response = double(code: '200')
    fragment = HTTParty::FragmentWithResponse.new("chunk", response)
    expect(fragment.code).to eq(200)
    expect(fragment.http_response).to eq response
  end
end
