When /I call HTTParty#get with '(.*)'$/ do |url|
  begin
    @response_from_httparty = HTTParty.get("http://#{@host_and_port}#{url}")
  rescue HTTParty::RedirectionTooDeep => e
    @exception_from_httparty = e
  end
end

When /I call HTTParty#get with '(.*)' and a basic_auth hash:/ do |url, auth_table|
  h = auth_table.hashes.first
  @response_from_httparty = HTTParty.get(
    "http://#{@host_and_port}#{url}",
    :basic_auth => { :username => h["username"], :password => h["password"] }
  )
end
