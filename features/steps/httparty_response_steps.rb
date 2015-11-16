# Not needed anymore in ruby 2.0, but needed to resolve constants
# in nested namespaces. This is taken from rails :)
def constantize(camel_cased_word)
  names = camel_cased_word.split('::')
  names.shift if names.empty? || names.first.empty?

  constant = Object
  names.each do |name|
    constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
  end
  constant
end

Then /it should return an? ([\w\:]+)$/ do |class_string|
  expect(@response_from_httparty.parsed_response).to be_a(Object.const_get(class_string))
end

Then /the return value should match '(.*)'/ do |expected_text|
  expect(@response_from_httparty.parsed_response).to eq(expected_text)
end

Then /it should return a Hash equaling:/ do |hash_table|
  expect(@response_from_httparty.parsed_response).to be_a(Hash)
  expect(@response_from_httparty.keys.length).to eq(hash_table.rows.length)
  hash_table.hashes.each do |pair|
    key, value = pair["key"], pair["value"]
    expect(@response_from_httparty.keys).to include(key)
    expect(@response_from_httparty[key]).to eq(value)
  end
end

Then /it should return an Array equaling:/ do |array|
  expect(@response_from_httparty.parsed_response).to be_a(Array)
  expect(@response_from_httparty.parsed_response).to eq(array.raw)
end

Then /it should return a response with a (\d+) response code/ do |code|
  expect(@response_from_httparty.code).to eq(code.to_i)
end

Then /it should return a response with a (.*) content\-encoding$/ do |content_type|
  expect(@response_from_httparty.headers['content-encoding']).to eq('gzip')
end

Then /it should return a response with a blank body$/ do
  expect(@response_from_httparty.body).to be_nil
end

Then /it should raise (?:an|a) ([\w:]+) exception/ do |exception|
  expect(@exception_from_httparty).to_not be_nil
  expect(@exception_from_httparty).to be_a constantize(exception)
end

Then /it should not raise (?:an|a) ([\w:]+) exception/ do |exception|
  expect(@exception_from_httparty).to be_nil
end
