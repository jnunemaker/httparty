When /^I set my HTTParty timeout option to (\d+)$/ do |timeout|
  @request_options[:timeout] = timeout.to_i
end

When /^I set my HTTParty open_timeout option to (\d+)$/ do |timeout|
  @request_options[:open_timeout] = timeout.to_i
end

When /^I set my HTTParty read_timeout option to (\d+)$/ do |timeout|
  @request_options[:read_timeout] = timeout.to_i
end

When /^I set my HTTParty header '(.*)' to value '(.*)'$/ do |name, value|
  @request_options[:headers] ||= {}
  @request_options[:headers][name] = value
end

When /I set my HTTParty logger option/ do
  # TODO: make the IO something portable
  @request_options[:logger] = Logger.new("/dev/null")
end

When /I set my HTTParty parser option to a proc/ do
  @request_options[:parser] = proc { |body| body }
end

When /I call HTTParty#get with '(.*)'$/ do |url|
  begin
    @response_from_httparty = HTTParty.get("http://#{@host_and_port}#{url}", @request_options)
  rescue HTTParty::RedirectionTooDeep, Timeout::Error => e
    @exception_from_httparty = e
  end
end

When /^I call HTTParty#head with '(.*)'$/ do |url|
  begin
    @response_from_httparty = HTTParty.head("http://#{@host_and_port}#{url}", @request_options)
  rescue HTTParty::RedirectionTooDeep, Timeout::Error => e
    @exception_from_httparty = e
  end
end

When /I call HTTParty#get with '(.*)' and a basic_auth hash:/ do |url, auth_table|
  h = auth_table.hashes.first
  @response_from_httparty = HTTParty.get(
    "http://#{@host_and_port}#{url}",
    basic_auth: { username: h["username"], password: h["password"] }
  )
end

When /I call HTTParty#get with '(.*)' and a digest_auth hash:/ do |url, auth_table|
  h = auth_table.hashes.first
  @response_from_httparty = HTTParty.get(
    "http://#{@host_and_port}#{url}",
    digest_auth: { username: h["username"], password: h["password"] }
  )
end

When /I call Marshal\.dump on the response/ do
  begin
    Marshal.dump(@response_from_httparty)
  rescue TypeError => e
    @exception_from_httparty = e
  end
end
