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

  it 'isolates arrays and nested hashes added to the parent after subclasses exist' do
    parent = Class.new { include HTTParty }
    child = Class.new(parent)
    sibling = Class.new(parent)
    parent.raise_on [404]
    parent.default_params nested: { tags: ['one'] }

    child.default_options[:raise_on] << 500
    child.default_options[:default_params][:nested][:tags] << 'two'

    expect(parent.default_options[:raise_on]).to eq([404])
    expect(sibling.default_options[:raise_on]).to eq([404])
    expect(parent.default_options[:default_params]).to eq(nested: { tags: ['one'] })
    expect(sibling.default_options[:default_params]).to eq(nested: { tags: ['one'] })
  end

  it 'preserves array subclasses and frozen state while isolating nested values' do
    array_class = Class.new(Array)
    values = array_class.new([{ tags: ['one'] }]).freeze
    parent = Class.new { include HTTParty }
    parent.default_params values: values
    child = Class.new(parent)
    copy = child.default_options[:default_params][:values]

    expect(copy).to be_a(array_class)
    expect(copy).to be_frozen
    expect(copy).not_to equal(values)
    copy[0][:tags] << 'two'
    expect(values[0][:tags]).to eq(['one'])
    expect { copy << 'more' }.to raise_error(FrozenError)
  end
end
