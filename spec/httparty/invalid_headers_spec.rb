require 'spec_helper'

RSpec.describe HTTParty, 'with request headers that are not a hash' do
  it 'raises the documented ArgumentError' do
    expect {
      HTTParty.get('http://example.com/', headers: 'X-Foo: bar')
    }.to raise_error(ArgumentError, ':headers must be a hash')
  end

  it 'raises the documented ArgumentError when the class has default headers' do
    client = Class.new do
      include HTTParty
      headers 'Accept' => 'application/json'
    end

    expect {
      client.get('http://example.com/', headers: 'X-Foo: bar')
    }.to raise_error(ArgumentError, ':headers must be a hash')
  end

  it 'raises the documented ArgumentError when cookies are set' do
    expect {
      HTTParty.get('http://example.com/', headers: 'X-Foo: bar', cookies: { a: '1' })
    }.to raise_error(ArgumentError, ':headers must be a hash')
  end
end
