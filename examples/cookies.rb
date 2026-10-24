$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'httparty'
require 'pp'

# postman-echo.com/cookies echoes back the cookies it receives.
class PostmanEcho
  include HTTParty
  base_uri 'https://postman-echo.com'
  cookies flavor: 'oatmeal' # sent with every request from this class
end

pp PostmanEcho.get('/cookies')['cookies'] # => {"flavor"=>"oatmeal"}

# Collect the cookies a server sets and send them back on a later request.
response = PostmanEcho.get('/cookies/set', query: { size: 'large' }, follow_redirects: false)
jar = HTTParty::CookieHash.new
response.headers.get_fields('Set-Cookie').each { |cookie| jar.add_cookies(cookie) }

pp PostmanEcho.get('/cookies', cookies: jar)['cookies'].slice('flavor', 'size')
# => {"flavor"=>"oatmeal", "size"=>"large"}
