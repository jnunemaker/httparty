require File.join(File.dirname(__FILE__), '..', 'spec_helper')

class Foo
  extend Web::Callbacks
  
  add_callback 'after_initialize' do
    'running after_initialize'
  end
  
  add_callback 'after_request' do
    'running after_request'
  end
  
  add_callback 'after_request' do
    'another callback for after_request'
  end
end

describe Web::Callbacks do
  it 'should know the callbacks that have been added' do
    Foo.callbacks.keys.should == %w[after_request after_initialize]
  end
  
  it 'should be able to add callbacks' do
    Foo.add_callback('foobar') do
      'do foobar'
    end.first.kind_of?(Proc).should == true
  end
  
  it 'should be able to run a callback' do
    Foo.run_callback('after_initialize').should == ['running after_initialize']
  end
  
  it 'should be able to run multiple callbacks' do
    Foo.run_callback('after_request').should == ['running after_request', 'another callback for after_request']
  end
end