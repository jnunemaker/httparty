dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require File.join(dir, 'httparty')

class TripIt
  include HTTParty
  base_uri 'http://www.tripit.com'
  debug_output

  def initialize(email, password)
    @email = email
    response = self.class.get('/account/login')
    response = self.class.post(
      '/account/login',
      body: {
        login_email_address: email,
        login_password: password
      },
      headers: {'Cookie' => response.headers['Set-Cookie']}
    )
    @cookie = response.request.options[:headers]['Cookie']
  end

  def account_settings
    self.class.get('/account/edit', headers: {'Cookie' => @cookie})
  end

  def logged_in?
    account_settings.include? "You're logged in as #{@email}"
  end
end

tripit = TripIt.new('email', 'password')
puts "Logged in: #{tripit.logged_in?}"
