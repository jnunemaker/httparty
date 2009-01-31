class HTTParty::CookieHash < Hash #:nodoc:
  def add_cookies(hash)
    merge!(hash)
  end

  def to_cookie_string
    collect { |k, v| "#{k}=#{v}" }.join("; ")
  end
end
