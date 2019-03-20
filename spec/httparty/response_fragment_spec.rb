require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

RSpec.describe HTTParty::ResponseFragment do
  it "access to fragment" do
    fragment = HTTParty::ResponseFragment.new("chunk", nil, nil)
    expect(fragment).to eq("chunk")
  end

  it "has access to delegators" do
    response = double(code: '200')
    connection = double
    fragment = HTTParty::ResponseFragment.new("chunk", response, connection)
    expect(fragment.code).to eq(200)
    expect(fragment.http_response).to eq response
    expect(fragment.connection).to eq connection
  end
end
