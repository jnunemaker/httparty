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

Then /it should return an? (\w+)$/ do |class_string|
  @response_from_httparty.should be_an_instance_of(class_string.class)
end

Then /the return value should match '(.*)'/ do |expected_text|
  @response_from_httparty.should eql(expected_text)
end

Then /it should return a Hash equaling:/ do |hash_table|
  @response_from_httparty.should be_an_instance_of(Hash)
  @response_from_httparty.keys.length.should eql(hash_table.rows.length)
  hash_table.hashes.each do |pair|
    key, value = pair["key"], pair["value"]
    @response_from_httparty.keys.should include(key)
    @response_from_httparty[key].should eql(value)
  end
end

Then /it should return a response with a (\d+) response code/ do |code|
  @response_from_httparty.code.should eql(code.to_i)
end

Then /it should return a response with a (.*) content\-encoding$/ do |content_type|
  @response_from_httparty.headers['content-encoding'].should eql('gzip')
end

Then /it should return a response with a blank body$/ do
  @response_from_httparty.body.should be(nil)
end

Then /it should raise (?:an|a) ([\w:]+) exception/ do |exception|
  @exception_from_httparty.should_not be_nil
  @exception_from_httparty.should be_a constantize(exception)
end
