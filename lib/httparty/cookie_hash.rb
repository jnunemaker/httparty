class HTTParty::CookieHash < Hash #:nodoc:
  CLIENT_COOKIES = %w(path expires domain path secure httponly)

  def add_cookies(value)
    case value
    when Hash
      merge!(value)
    when String
      value.split('; ').each do |cookie|
        array = cookie.split('=', 2)
        self[array[0].to_sym] = array[1]
      end
    else
      raise "add_cookies only takes a Hash or a String"
    end
  end

  def to_cookie_string
    select { |k, v| !CLIENT_COOKIES.include?(k.to_s.downcase) }.collect { |k, v| "#{k}=#{v}" }.join("; ")
  end
end
