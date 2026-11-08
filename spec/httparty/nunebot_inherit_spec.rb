require 'spec_helper'

RSpec.describe HTTParty::ModuleInheritableAttributes, 'array option isolation' do
  it 'does not share nested arrays with a parent or sibling client' do
    parent = Class.new do
      include HTTParty
      default_params tags: ['one'], groups: [{ names: [['original']] }]
    end
    child = Class.new(parent)
    sibling = Class.new(parent)

    child.default_options[:default_params][:tags] << 'two'
    child.default_options[:default_params][:groups][0][:names][0] << 'changed'

    expect(parent.default_options[:default_params]).to eq(tags: ['one'], groups: [{ names: [['original']] }])
    expect(sibling.default_options[:default_params]).to eq(parent.default_options[:default_params])
    expect(child.default_options[:default_params][:tags]).to eq(['one', 'two'])
  end

  it 'isolates a top-level array across multiple inheritance levels' do
    parent = Class.new do
      include HTTParty
      raise_on [404]
    end
    child = Class.new(parent)
    grandchild = Class.new(child)
    grandchild.default_options[:raise_on] << 500

    expect(parent.default_options[:raise_on]).to eq([404])
    expect(child.default_options[:raise_on]).to eq([404])
    expect(grandchild.default_options[:raise_on]).to eq([404, 500])
  end
end
